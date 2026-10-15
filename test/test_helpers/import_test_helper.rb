module ImportTestHelper
  def import_file(name)
    Rack::Test::UploadedFile.new(file_fixture("imports/#{name}"))
  end

  def upload(name, content)
    Tempfile.create([ "upload", File.extname(name) ]) do |file|
      file.binmode
      file.write(content)
      file.close
      Rack::Test::UploadedFile.new(file.path, original_filename: name)
    end
  end

  def xlsx(entries)
    Zip::OutputStream.write_buffer do |zip|
      entries.each do |name, content|
        zip.put_next_entry(name)
        zip.write(content)
      end
    end.string
  end
end

ActiveSupport.on_load(:active_support_test_case) do
  include ImportTestHelper
end
