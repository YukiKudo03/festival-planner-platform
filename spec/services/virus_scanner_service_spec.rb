require 'rails_helper'

RSpec.describe VirusScannerService, type: :service do
  let(:safe_file_path) { Rails.root.join('spec/fixtures/files/test_document.pdf') }
  let(:test_virus_path) { Rails.root.join('spec/fixtures/files/eicar_test.txt') }

  before do
    # Create test files
    FileUtils.mkdir_p(File.dirname(safe_file_path))
    FileUtils.mkdir_p(File.dirname(test_virus_path))
    
    File.write(safe_file_path, "Safe PDF content") unless File.exist?(safe_file_path)
    File.write(test_virus_path, "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*") unless File.exist?(test_virus_path)
  end

  describe '.scan_file' do
    context 'with mock scanner' do
      before do
        allow(described_class).to receive(:detect_scanner).and_return(:mock)
      end

      it 'scans safe files successfully' do
        result = described_class.scan_file(safe_file_path)
        
        expect(result).to be_a(Hash)
        expect(result[:safe]).to be true
        expect(result[:scanner]).to eq('mock')
        expect(result[:scan_time]).to be > 0
      end

      it 'detects test virus files' do
        result = described_class.scan_file(test_virus_path)
        
        expect(result).to be_a(Hash)
        expect(result[:safe]).to be false
        expect(result[:scanner]).to eq('mock')
        expect(result[:threat_name]).to eq('EICAR-Test-File')
      end
    end

    context 'with ClamAV scanner' do
      before do
        allow(described_class).to receive(:detect_scanner).and_return(:clamav)
        allow(described_class).to receive(:system).and_return(true)
        allow($?).to receive(:exitstatus).and_return(0)
      end

      it 'uses ClamAV when available' do
        expect(described_class).to receive(:system).with(/clamscan/)
        
        result = described_class.scan_file(safe_file_path)
        expect(result[:scanner]).to eq('clamav')
      end
    end

    context 'with Windows Defender' do
      before do
        allow(described_class).to receive(:detect_scanner).and_return(:windows_defender)
        allow(described_class).to receive(:system).and_return(true)
        allow($?).to receive(:exitstatus).and_return(0)
      end

      it 'uses Windows Defender when available' do
        expect(described_class).to receive(:system).with(/MpCmdRun/)
        
        result = described_class.scan_file(safe_file_path)
        expect(result[:scanner]).to eq('windows_defender')
      end
    end

    context 'with VirusTotal API' do
      before do
        allow(described_class).to receive(:detect_scanner).and_return(:virustotal)
        stub_request(:post, "https://www.virustotal.com/vtapi/v2/file/scan")
          .to_return(status: 200, body: { scan_id: "test_scan_id" }.to_json)
        stub_request(:post, "https://www.virustotal.com/vtapi/v2/file/report")
          .to_return(status: 200, body: { 
            response_code: 1, 
            positives: 0, 
            total: 50 
          }.to_json)
      end

      it 'uses VirusTotal API when configured' do
        allow(Rails.application.credentials).to receive(:virustotal_api_key).and_return('test_api_key')
        
        result = described_class.scan_file(safe_file_path)
        expect(result[:scanner]).to eq('virustotal')
      end
    end

    context 'with nonexistent file' do
      it 'handles missing files gracefully' do
        result = described_class.scan_file('/nonexistent/file.txt')
        
        expect(result[:safe]).to be false
        expect(result[:error]).to include('not found')
      end
    end
  end

  describe '.detect_scanner' do
    context 'on macOS' do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('darwin')
      end

      it 'detects ClamAV when available' do
        allow(described_class).to receive(:system).with('which clamscan > /dev/null 2>&1').and_return(true)
        
        scanner = described_class.send(:detect_scanner)
        expect(scanner).to eq(:clamav)
      end

      it 'falls back to mock when no scanner available' do
        allow(described_class).to receive(:system).and_return(false)
        
        scanner = described_class.send(:detect_scanner)
        expect(scanner).to eq(:mock)
      end
    end

    context 'on Windows' do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('mswin')
      end

      it 'detects Windows Defender when available' do
        allow(File).to receive(:exist?).with(/MpCmdRun\.exe/).and_return(true)
        
        scanner = described_class.send(:detect_scanner)
        expect(scanner).to eq(:windows_defender)
      end
    end

    context 'on Linux' do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return('linux')
      end

      it 'detects ClamAV when available' do
        allow(described_class).to receive(:system).with('which clamscan > /dev/null 2>&1').and_return(true)
        
        scanner = described_class.send(:detect_scanner)
        expect(scanner).to eq(:clamav)
      end
    end
  end

  describe '.scan_with_clamav' do
    it 'executes clamscan command' do
      expect(described_class).to receive(:system).with(/clamscan.*#{safe_file_path}/)
      allow($?).to receive(:exitstatus).and_return(0)
      
      result = described_class.send(:scan_with_clamav, safe_file_path)
      expect(result[:scanner]).to eq('clamav')
    end

    it 'detects infected files' do
      allow(described_class).to receive(:system).and_return(true)
      allow($?).to receive(:exitstatus).and_return(1)
      
      result = described_class.send(:scan_with_clamav, test_virus_path)
      expect(result[:safe]).to be false
    end
  end

  describe '.scan_with_windows_defender' do
    it 'executes MpCmdRun command' do
      expect(described_class).to receive(:system).with(/MpCmdRun.*#{safe_file_path}/)
      allow($?).to receive(:exitstatus).and_return(0)
      
      result = described_class.send(:scan_with_windows_defender, safe_file_path)
      expect(result[:scanner]).to eq('windows_defender')
    end
  end

  describe '.scan_with_virustotal' do
    let(:api_key) { 'test_api_key' }

    before do
      stub_request(:post, "https://www.virustotal.com/vtapi/v2/file/scan")
        .to_return(status: 200, body: { scan_id: "test_scan_id" }.to_json)
      stub_request(:post, "https://www.virustotal.com/vtapi/v2/file/report")
        .to_return(status: 200, body: { 
          response_code: 1, 
          positives: 0, 
          total: 50 
        }.to_json)
    end

    it 'uploads file and gets scan results' do
      result = described_class.send(:scan_with_virustotal, safe_file_path, api_key)
      
      expect(result[:scanner]).to eq('virustotal')
      expect(result[:safe]).to be true
    end

    it 'detects threats when positives > 0' do
      stub_request(:post, "https://www.virustotal.com/vtapi/v2/file/report")
        .to_return(status: 200, body: { 
          response_code: 1, 
          positives: 5, 
          total: 50 
        }.to_json)
      
      result = described_class.send(:scan_with_virustotal, test_virus_path, api_key)
      expect(result[:safe]).to be false
    end
  end

  describe '.scan_with_mock' do
    it 'identifies EICAR test strings' do
      result = described_class.send(:scan_with_mock, test_virus_path)
      
      expect(result[:safe]).to be false
      expect(result[:threat_name]).to eq('EICAR-Test-File')
      expect(result[:scanner]).to eq('mock')
    end

    it 'considers other files safe' do
      result = described_class.send(:scan_with_mock, safe_file_path)
      
      expect(result[:safe]).to be true
      expect(result[:scanner]).to eq('mock')
    end
  end

  describe 'scanner availability' do
    it 'checks ClamAV availability' do
      expect(described_class).to respond_to(:clamav_available?)
    end

    it 'checks Windows Defender availability' do
      expect(described_class).to respond_to(:windows_defender_available?)
    end

    it 'checks VirusTotal API configuration' do
      expect(described_class).to respond_to(:virustotal_available?)
    end
  end
end