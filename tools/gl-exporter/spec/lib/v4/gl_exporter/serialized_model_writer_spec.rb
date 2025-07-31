require "spec_helper"

require "tmpdir"
require "fileutils"

describe GlExporter::SerializedModelWriter, :v4 do
  let(:data) {{
    "something" => "this is a thing",
    "something2" => "this is also a thing"
  }}
  let(:dir) { Dir.mktmpdir("gl-export-test") }
  let(:subject) { GlExporter::SerializedModelWriter.new(dir, "organizations") }

  after do
    FileUtils.remove_entry_secure(dir)
  end

  it "rolls over a file" do
    101.times { subject.add(data) }
    subject.close

    expect(data_in("organizations_000001.json").size).to eq(100)
    expect(data_in("organizations_000002.json").size).to eq(1)
  end

  it "jsonifies the data" do
    subject.add(data)
    subject.close

    expect(data_in("organizations_000001.json")).to eq([data])
  end

  def data_in(filename)
    path = File.join(dir, filename)
    json_data = File.read(path)
    JSON.load(json_data)
  end
end
