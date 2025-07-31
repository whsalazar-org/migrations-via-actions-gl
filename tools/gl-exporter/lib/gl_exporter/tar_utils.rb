require "rubygems/package"
require "tempfile"
require "zlib"

class GlExporter
  module TarUtils

    # Create a gzipped archive with the contents of source_path.
    #
    # @param [String, Pathname] source_path path to files that need archived.
    # @param [String, Pathname] archive_path path and filename for created archive.
    # @return [String, Pathname]
    def create_archive(source_path, archive_path)
      options = ["-czf", "#{archive_path}", "-C", "#{source_path}", "."]

      # On OSX add the --disable-copyfile option to prevent ._ entries.
      if RbConfig::CONFIG['host_os'].start_with? "darwin"
        options.unshift("--disable-copyfile")
      end

      child = POSIX::Spawn::Child.new("tar", *options)
      raise child.err unless child.success?

      return archive_path
    end

    # Extract file(s) from archive to destination path and optionally
    # cleanup extracted files after yielding a block if it is provided.
    #
    # @param [String, Pathname] archive_path path to archive
    # @param [String, Pathname] destination_path destination path for files
    # @return [String, Pathname] destination_path (or NilClass if block given)
    def extract_archive(archive_path, destination_path, &block)
      options = ["-xzf", "#{archive_path}", "-C", "#{destination_path}"]

      FileUtils.mkdir_p(destination_path)

      child = POSIX::Spawn::Child.new("tar", *options)
      raise child.err unless child.success?

      if block_given? && File.exist?(destination_path)
        yield
        FileUtils.rm_rf(destination_path, :secure => true)
        return nil
      else
        return destination_path
      end
    end

    def read_from_archive(pattern)
      Dir["#{migration_path}/#{pattern}"].each do |file_path|
        File.open(file_path, "r") do |file|
          yield(file)
        end
      end
    end
  end
end
