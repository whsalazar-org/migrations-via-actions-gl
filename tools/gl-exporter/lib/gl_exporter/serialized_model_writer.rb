require "active_support/inflector/inflections"

class GlExporter
  class SerializedModelWriter
    def initialize(dir, prefix)
      @dir = dir
      @prefix = prefix.pluralize
    end

    attr_reader :dir, :prefix

    # Jsonifies and writes to the file, rolling over to the next if necessary
    def add(data)
      if count == 0
        fh.puts "["
      else
        fh.puts ","
      end
      JSON.dump data, fh
      self.count += 1
      if count >= 100
        close
      end
    end

    # Completes the current file, if there's one open, and prepares for the next one.
    def close
      if @fh
        @fh.puts "]"
        @fh.close
        @fh = nil
        self.index += 1
        self.count = 0
      end
    end
    
    # The current archive file.
    def fh
      @fh ||= File.open(build_filename, "w")
    end

    # Generates the name of the current archive file.
    #
    # e.g. "users_000023.json"
    def build_filename
      "%s/%s_%06d.json" % [dir, prefix, index]
    end

    # The number of records in the current file.
    def count
      @count ||= 0
    end
    attr_writer :count

    # The number of the current file.
    def index
      @index ||= 1
    end
    attr_writer :index
  end
end
