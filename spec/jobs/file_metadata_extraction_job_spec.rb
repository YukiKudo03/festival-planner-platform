require 'rails_helper'

RSpec.describe FileMetadataExtractionJob, type: :job do
  let(:user) { create(:user) }
  let(:file_metadata) { create(:file_metadata, uploaded_by: user) }

  describe '#perform' do
    context 'with PDF file' do
      let(:pdf_path) { Rails.root.join('spec/fixtures/files/test_document.pdf') }

      before do
        file_metadata.update!(
          file_path: pdf_path.to_s,
          content_type: 'application/pdf',
          original_filename: 'test_document.pdf'
        )
      end

      it 'extracts metadata from PDF file' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.extracted_metadata).to be_present
        expect(file_metadata.extraction_status).to eq('completed')
      end

      it 'extracts text content from PDF' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.extracted_text).to be_present
      end

      it 'calculates file checksum' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.file_checksum).to be_present
        expect(file_metadata.file_checksum).to match(/^[a-f0-9]{64}$/)
      end
    end

    context 'with image file' do
      let(:image_path) { Rails.root.join('spec/fixtures/files/test_image.jpg') }

      before do
        # Create a simple test image
        FileUtils.mkdir_p(File.dirname(image_path))
        File.write(image_path, "\xFF\xD8\xFF\xE0\x00\x10JFIF") unless File.exist?(image_path)
        
        file_metadata.update!(
          file_path: image_path.to_s,
          content_type: 'image/jpeg',
          original_filename: 'test_image.jpg'
        )
      end

      it 'extracts image metadata' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.extracted_metadata).to include('format')
        expect(file_metadata.extraction_status).to eq('completed')
      end

      it 'extracts image dimensions if available' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        metadata = file_metadata.extracted_metadata
        expect(metadata).to be_present
      end
    end

    context 'with text file' do
      let(:text_path) { Rails.root.join('spec/fixtures/files/test_document.txt') }

      before do
        FileUtils.mkdir_p(File.dirname(text_path))
        File.write(text_path, "This is a test document with some content.") unless File.exist?(text_path)
        
        file_metadata.update!(
          file_path: text_path.to_s,
          content_type: 'text/plain',
          original_filename: 'test_document.txt'
        )
      end

      it 'extracts text content' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.extracted_text).to include('test document')
        expect(file_metadata.extraction_status).to eq('completed')
      end

      it 'counts lines and characters' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        metadata = file_metadata.extracted_metadata
        expect(metadata).to include('line_count', 'character_count')
      end
    end

    context 'with nonexistent file' do
      before do
        file_metadata.update!(
          file_path: '/nonexistent/file.pdf',
          content_type: 'application/pdf'
        )
      end

      it 'handles missing files gracefully' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.extraction_status).to eq('failed')
        expect(file_metadata.extraction_error).to include('not found')
      end
    end

    context 'with unsupported file type' do
      let(:binary_path) { Rails.root.join('spec/fixtures/files/binary_file.bin') }

      before do
        FileUtils.mkdir_p(File.dirname(binary_path))
        File.write(binary_path, "\x00\x01\x02\x03\x04\x05") unless File.exist?(binary_path)
        
        file_metadata.update!(
          file_path: binary_path.to_s,
          content_type: 'application/octet-stream',
          original_filename: 'binary_file.bin'
        )
      end

      it 'handles unsupported files gracefully' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.extraction_status).to eq('completed')
        expect(file_metadata.extracted_metadata).to include('file_type' => 'binary')
      end
    end

    context 'with corrupted file' do
      let(:corrupted_path) { Rails.root.join('spec/fixtures/files/corrupted.pdf') }

      before do
        FileUtils.mkdir_p(File.dirname(corrupted_path))
        File.write(corrupted_path, "This is not a PDF file") unless File.exist?(corrupted_path)
        
        file_metadata.update!(
          file_path: corrupted_path.to_s,
          content_type: 'application/pdf',
          original_filename: 'corrupted.pdf'
        )
      end

      it 'handles corrupted files gracefully' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.extraction_status).to eq('failed')
        expect(file_metadata.extraction_error).to be_present
      end
    end
  end

  describe 'job configuration' do
    it 'has correct queue name' do
      expect(described_class.queue_name).to eq('file_processing')
    end

    it 'retries on failure' do
      expect(described_class.retry_limit).to be > 0
    end
  end

  describe 'error handling' do
    context 'with database errors' do
      it 'handles record not found' do
        expect {
          described_class.perform_now(999999)
        }.not_to raise_error
      end
    end

    context 'with file system errors' do
      before do
        allow(File).to receive(:read).and_raise(Errno::EACCES, "Permission denied")
      end

      it 'handles permission errors' do
        expect {
          described_class.perform_now(file_metadata.id)
        }.not_to raise_error
        
        file_metadata.reload
        expect(file_metadata.extraction_status).to eq('failed')
      end
    end

    context 'with external tool errors' do
      before do
        allow(described_class).to receive(:system).and_return(false)
      end

      it 'handles external tool failures' do
        described_class.perform_now(file_metadata.id)
        
        file_metadata.reload
        expect(file_metadata.extraction_status).to eq('completed')
      end
    end
  end

  describe 'performance' do
    it 'completes extraction within reasonable time' do
      start_time = Time.current
      
      described_class.perform_now(file_metadata.id)
      
      elapsed_time = Time.current - start_time
      expect(elapsed_time).to be < 10.seconds
    end

    it 'processes multiple files efficiently' do
      file_metadatas = create_list(:file_metadata, 3, uploaded_by: user)
      
      start_time = Time.current
      
      file_metadatas.each do |fm|
        described_class.perform_now(fm.id)
      end
      
      elapsed_time = Time.current - start_time
      expect(elapsed_time).to be < 30.seconds
    end
  end

  describe 'callbacks and hooks' do
    it 'updates last_processed_at timestamp' do
      described_class.perform_now(file_metadata.id)
      
      file_metadata.reload
      expect(file_metadata.last_processed_at).to be_within(1.second).of(Time.current)
    end

    it 'increments processing_attempts counter' do
      initial_attempts = file_metadata.processing_attempts || 0
      
      described_class.perform_now(file_metadata.id)
      
      file_metadata.reload
      expect(file_metadata.processing_attempts).to eq(initial_attempts + 1)
    end

    it 'triggers webhooks for successful extraction' do
      webhook_url = 'https://example.com/webhook'
      file_metadata.update!(webhook_url: webhook_url)
      
      stub_request(:post, webhook_url)
        .to_return(status: 200)
      
      described_class.perform_now(file_metadata.id)
      
      expect(WebMock).to have_requested(:post, webhook_url)
    end
  end
end