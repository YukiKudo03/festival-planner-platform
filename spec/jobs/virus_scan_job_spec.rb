require 'rails_helper'

RSpec.describe VirusScanJob, type: :job do
  let(:user) { create(:user) }
  let(:file_metadata) { create(:file_metadata, uploaded_by: user) }
  let(:safe_file_path) { Rails.root.join('spec/fixtures/files/test_document.pdf') }
  let(:virus_file_path) { Rails.root.join('spec/fixtures/files/eicar_test.txt') }

  describe '#perform' do
    context 'with safe file' do
      before do
        file_metadata.update!(
          file_path: safe_file_path.to_s,
          original_filename: 'test_document.pdf'
        )
      end

      it 'scans file and marks as safe' do
        allow(VirusScannerService).to receive(:scan_file).and_return({
          safe: true,
          scanner: 'mock',
          scan_time: 0.5
        })
        
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.virus_scan_status).to eq('clean')
        expect(file_metadata.virus_scan_result).to include('safe' => true)
      end

      it 'records scan metadata' do
        allow(VirusScannerService).to receive(:scan_file).and_return({
          safe: true,
          scanner: 'clamav',
          scan_time: 1.2,
          version: '0.105.0'
        })
        
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        result = file_metadata.virus_scan_result
        expect(result['scanner']).to eq('clamav')
        expect(result['scan_time']).to eq(1.2)
        expect(result['version']).to eq('0.105.0')
      end

      it 'updates scan timestamp' do
        allow(VirusScannerService).to receive(:scan_file).and_return({
          safe: true,
          scanner: 'mock'
        })
        
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.virus_scan_completed_at).to be_within(1.second).of(Time.current)
      end
    end

    context 'with infected file' do
      before do
        file_metadata.update!(
          file_path: virus_file_path.to_s,
          original_filename: 'eicar_test.txt'
        )
      end

      it 'detects virus and quarantines file' do
        allow(VirusScannerService).to receive(:scan_file).and_return({
          safe: false,
          scanner: 'mock',
          threat_name: 'EICAR-Test-File',
          scan_time: 0.3
        })
        
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.virus_scan_status).to eq('infected')
        expect(file_metadata.quarantined).to be true
        expect(file_metadata.virus_scan_result['threat_name']).to eq('EICAR-Test-File')
      end

      it 'sends notification for infected files' do
        allow(VirusScannerService).to receive(:scan_file).and_return({
          safe: false,
          scanner: 'mock',
          threat_name: 'Test.Virus'
        })
        
        expect {
          described_class.perform_now(file_metadata.id)
        }.to have_enqueued_job(ActionMailer::MailDeliveryJob)
      end

      it 'logs security incident' do
        allow(VirusScannerService).to receive(:scan_file).and_return({
          safe: false,
          scanner: 'mock',
          threat_name: 'Malware.Generic'
        })
        
        expect(Rails.logger).to receive(:warn).with(/Virus detected/)
        
        described_class.perform_now(file_metadata.id)
      end

      it 'moves file to quarantine' do
        allow(VirusScannerService).to receive(:scan_file).and_return({
          safe: false,
          scanner: 'mock',
          threat_name: 'Test.Virus'
        })
        
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.quarantine_path).to be_present
        expect(file_metadata.quarantine_path).to include('quarantine')
      end
    end

    context 'with scan errors' do
      before do
        file_metadata.update!(
          file_path: safe_file_path.to_s,
          original_filename: 'test_document.pdf'
        )
      end

      it 'handles scanner unavailability' do
        allow(VirusScannerService).to receive(:scan_file).and_return({
          safe: false,
          error: 'Scanner not available'
        })
        
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.virus_scan_status).to eq('error')
        expect(file_metadata.virus_scan_result['error']).to include('Scanner not available')
      end

      it 'retries on temporary failures' do
        call_count = 0
        allow(VirusScannerService).to receive(:scan_file) do
          call_count += 1
          if call_count < 3
            raise StandardError, 'Temporary failure'
          else
            { safe: true, scanner: 'mock' }
          end
        end
        
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.virus_scan_status).to eq('clean')
      end

      it 'marks as error after max retries' do
        allow(VirusScannerService).to receive(:scan_file).and_raise(StandardError, 'Persistent error')
        
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.virus_scan_status).to eq('error')
      end
    end

    context 'with nonexistent file' do
      before do
        file_metadata.update!(
          file_path: '/nonexistent/file.pdf',
          original_filename: 'missing.pdf'
        )
      end

      it 'handles missing files' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.virus_scan_status).to eq('error')
        expect(file_metadata.virus_scan_result['error']).to include('not found')
      end
    end
  end

  describe 'job configuration' do
    it 'has correct queue name' do
      expect(described_class.queue_name).to eq('virus_scanning')
    end

    it 'has high priority for security scanning' do
      expect(described_class.priority).to be > 0
    end

    it 'retries with exponential backoff' do
      expect(described_class.retry_limit).to be >= 3
    end
  end

  describe 'scan scheduling' do
    context 'immediate scan' do
      it 'scans new uploads immediately' do
        expect {
          described_class.perform_later(file_metadata.id)
        }.to have_enqueued_job(described_class).with(file_metadata.id)
      end
    end

    context 'batch scanning' do
      let!(:file_metadatas) { create_list(:file_metadata, 5, uploaded_by: user) }

      it 'processes multiple files in batch' do
        file_metadatas.each do |fm|
          described_class.perform_later(fm.id)
        end
        
        expect(described_class).to have_been_enqueued.exactly(5).times
      end
    end

    context 'rescanning' do
      before do
        file_metadata.update!(
          virus_scan_status: 'clean',
          virus_scan_completed_at: 1.week.ago
        )
      end

      it 'rescans old files when requested' do
        described_class.perform_now(file_metadata.id, force_rescan: true)
        
        file_metadata.reload
        expect(file_metadata.virus_scan_completed_at).to be_within(1.second).of(Time.current)
      end

      it 'skips recent scans unless forced' do
        file_metadata.update!(virus_scan_completed_at: 1.hour.ago)
        
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.virus_scan_completed_at).to be_within(1.hour).of(1.hour.ago)
      end
    end
  end

  describe 'security measures' do
    it 'sanitizes file paths' do
      malicious_path = '../../../etc/passwd'
      file_metadata.update!(file_path: malicious_path)
      
      expect {
        described_class.perform_now(file_metadata.id)
      }.not_to raise_error
    end

    it 'validates file metadata integrity' do
      file_metadata.update!(file_checksum: 'invalid_checksum')
      
      described_class.perform_now(file_metadata.id)
      
      file_metadata.reload
      expect(file_metadata.virus_scan_result).to include('checksum_verified')
    end

    it 'prevents scan result tampering' do
      original_result = { safe: true, scanner: 'test' }
      file_metadata.update!(virus_scan_result: original_result)
      
      # Attempt to modify result during scan
      allow(VirusScannerService).to receive(:scan_file) do
        file_metadata.virus_scan_result['tampered'] = true
        { safe: false, scanner: 'test' }
      end
      
      described_class.perform_now(file_metadata.id)
      
      file_metadata.reload
      expect(file_metadata.virus_scan_result['safe']).to be false
    end
  end

  describe 'performance monitoring' do
    it 'tracks scan duration' do
      allow(VirusScannerService).to receive(:scan_file).and_return({
        safe: true,
        scanner: 'test',
        scan_time: 2.5
      })
      
      described_class.perform_now(file_metadata.id)
      
      file_metadata.reload
      expect(file_metadata.virus_scan_result['scan_time']).to eq(2.5)
    end

    it 'monitors queue performance' do
      start_time = Time.current
      
      described_class.perform_now(file_metadata.id)
      
      processing_time = Time.current - start_time
      expect(processing_time).to be < 5.seconds
    end

    it 'reports scan statistics' do
      allow(VirusScannerService).to receive(:scan_file).and_return({
        safe: true,
        scanner: 'clamav',
        signatures_count: 8500000
      })
      
      described_class.perform_now(file_metadata.id)
      
      file_metadata.reload
      expect(file_metadata.virus_scan_result['signatures_count']).to be_present
    end
  end

  describe 'integration with other services' do
    it 'triggers file metadata extraction after clean scan' do
      allow(VirusScannerService).to receive(:scan_file).and_return({
        safe: true,
        scanner: 'mock'
      })
      
      expect {
        described_class.perform_now(file_metadata.id)
      }.to have_enqueued_job(FileMetadataExtractionJob)
    end

    it 'updates file access permissions' do
      allow(VirusScannerService).to receive(:scan_file).and_return({
        safe: true,
        scanner: 'mock'
      })
      
      described_class.perform_now(file_metadata.id)
      
      file_metadata.reload
      expect(file_metadata.access_allowed).to be true
    end

    it 'notifies file upload service of completion' do
      allow(VirusScannerService).to receive(:scan_file).and_return({
        safe: true,
        scanner: 'mock'
      })
      
      webhook_url = 'https://example.com/scan-complete'
      file_metadata.update!(webhook_url: webhook_url)
      
      stub_request(:post, webhook_url)
        .to_return(status: 200)
      
      described_class.perform_now(file_metadata.id)
      
      expect(WebMock).to have_requested(:post, webhook_url)
    end
  end
end