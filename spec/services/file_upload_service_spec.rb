require 'rails_helper'

RSpec.describe FileUploadService, type: :service do
  let(:user) { create(:user) }
  let(:festival) { create(:festival) }
  let(:valid_file) { fixture_file_upload('spec/fixtures/files/test_document.pdf', 'application/pdf') }
  let(:invalid_file) { fixture_file_upload('spec/fixtures/files/malicious.exe', 'application/x-executable') }
  let(:large_file) { fixture_file_upload('spec/fixtures/files/large_file.pdf', 'application/pdf') }

  describe '#upload_files' do
    context 'with valid files' do
      let(:file_params) do
        {
          files: [valid_file],
          uploaded_by: user,
          upload_context: 'vendor_application',
          metadata: { description: 'Business license' }
        }
      end

      it 'successfully uploads files' do
        allow(VirusScannerService).to receive(:scan_file).and_return({ safe: true, scanner: 'mock' })
        
        result = described_class.upload_files(file_params)
        
        expect(result[:success]).to be true
        expect(result[:files]).to be_present
        expect(result[:files].first).to have_key(:id)
        expect(result[:files].first).to have_key(:filename)
      end

      it 'creates file metadata record' do
        allow(VirusScannerService).to receive(:scan_file).and_return({ safe: true, scanner: 'mock' })
        
        expect {
          described_class.upload_files(file_params)
        }.to change(FileMetadata, :count).by(1)
      end

      it 'logs file access' do
        allow(VirusScannerService).to receive(:scan_file).and_return({ safe: true, scanner: 'mock' })
        
        expect {
          described_class.upload_files(file_params)
        }.to change(FileAccessLog, :count).by(1)
      end
    end

    context 'with virus-infected files' do
      let(:file_params) do
        {
          files: [valid_file],
          uploaded_by: user,
          upload_context: 'vendor_application'
        }
      end

      it 'rejects infected files' do
        allow(VirusScannerService).to receive(:scan_file).and_return({ 
          safe: false, 
          scanner: 'mock', 
          threat_name: 'Test.Virus' 
        })
        
        result = described_class.upload_files(file_params)
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include(/virus detected/i)
      end
    end

    context 'with invalid file types' do
      let(:file_params) do
        {
          files: [invalid_file],
          uploaded_by: user,
          upload_context: 'vendor_application'
        }
      end

      it 'rejects invalid file types' do
        result = described_class.upload_files(file_params)
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include(/not allowed/i)
      end
    end

    context 'with oversized files' do
      let(:file_params) do
        {
          files: [large_file],
          uploaded_by: user,
          upload_context: 'vendor_application'
        }
      end

      before do
        stub_const("FileUploadService::MAX_FILE_SIZE", 1.megabyte)
      end

      it 'rejects oversized files' do
        result = described_class.upload_files(file_params)
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include(/too large/i)
      end
    end

    context 'without required parameters' do
      it 'fails without files' do
        result = described_class.upload_files({
          uploaded_by: user,
          upload_context: 'vendor_application'
        })
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include(/no files/i)
      end

      it 'fails without uploader' do
        result = described_class.upload_files({
          files: [valid_file],
          upload_context: 'vendor_application'
        })
        
        expect(result[:success]).to be false
        expect(result[:errors]).to include(/uploader required/i)
      end
    end
  end

  describe '#validate_file' do
    it 'validates file type' do
      result = described_class.send(:validate_file, valid_file)
      expect(result[:valid]).to be true
    end

    it 'rejects invalid file types' do
      result = described_class.send(:validate_file, invalid_file)
      expect(result[:valid]).to be false
      expect(result[:error]).to include(/not allowed/i)
    end
  end

  describe '#extract_metadata' do
    it 'extracts basic file metadata' do
      metadata = described_class.send(:extract_metadata, valid_file)
      
      expect(metadata).to include(:original_filename, :content_type, :size)
      expect(metadata[:original_filename]).to eq('test_document.pdf')
      expect(metadata[:content_type]).to eq('application/pdf')
    end
  end

  describe '.allowed_file_types' do
    it 'returns allowed file extensions' do
      types = described_class.allowed_file_types
      
      expect(types).to include('.pdf', '.jpg', '.png', '.doc', '.docx')
      expect(types).not_to include('.exe', '.bat', '.sh')
    end
  end

  describe '.max_file_size' do
    it 'returns maximum file size in bytes' do
      size = described_class.max_file_size
      expect(size).to be > 0
      expect(size).to eq(10.megabytes)
    end
  end
end