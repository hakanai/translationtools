module PropTool
  class Properties

    # Holds one entry in a properties file.
    class Entry
      attr_reader :comment_lines
      attr_reader :key
      attr_accessor :value

      def initialize(comment_lines, key, value)
        @comment_lines = comment_lines
        @key = key
        @value = value
      end

      def store(io, native)
        @comment_lines.each { |line| io.write("#{line}\n") }
        io.write("#{PropertiesFormat.escape_key(@key, native)}=#{PropertiesFormat.escape_value(@value, native)}\n")
      end
    end

    def initialize(hash = {})
      @hash = hash
    end

    # Loads the properties from a file.
    # @param file [String]
    # @param options [Hash]:
    #         :encoding - the encoding to read the file in (default is the standard ISO-8859-1.)
    def self.load(file, options = {})
      options = { :encoding => 'ISO-8859-1' }.merge!(options)
      properties = Properties.new
      File.open(file.to_s, 'r', :encoding => options[:encoding]) do |io|
        comment_lines = []
        continuation_key = continuation_value = nil
        io.each_line do |line|

          # Converting to UTF-8 eagerly so that output works.
          line.encode!('UTF-8')

          # BOM on front of UTF-8 files is not recommended but some people do it anyway.
          #XXX: Technically this could be restricted to the first line or for Unicode formats only.
          line.sub!(/^\uFEFF/, '')

          line.strip!

          if line == '' || line =~ /^#/
            comment_lines << line
            next
          end

          # These will be nil for the first line of a property definition.
          key = continuation_key
          value = continuation_value
          continuation = !!(line =~ /\\$/)

          if key
            value += PropertiesFormat.unescape(line)
          else
            #XXX: This only supports = as the separator. Technically the format permits colon or even just space.
            if line =~ /^(.*?)\s*=\s*(.*?)\\?$/
              key, value = PropertiesFormat.unescape($1), PropertiesFormat.unescape($2)
            else
              raise "Not properties format? #{line} (file: #{file})"
            end
          end

          if continuation
            continuation_key = key
            continuation_value = value
          else
            continuation_key = continuation_value = nil
            properties[key] = Entry.new(comment_lines, key, value)
            comment_lines = []
          end
        end
      end
      properties
    end

    # Saves the properties to a file.
    # @param file [String]
    # @param options [Hash]:
    #         :encoding - the encoding to write the file in (default is the standard ISO-8859-1.)
    #                     if specified, non-ASCII characters will not be escaped.
    def store(file, options = {})
      options = { :encoding => 'ISO-8859-1' }.merge!(options)
      native = (options[:encoding] != 'ISO-8859-1')
      File.open(file.to_s, 'w', :encoding => options[:encoding]) do |io|
        each_value { |entry| entry.store(io, native) }
      end
    end

    # Merges new properties into these. If a property exists in both, its value is replaced with the value
    # from the properties passed in but comments on the original are retained.
    # As the method name suggests, the changes are done inline rather than creating a copy.
    # A detail of Ruby (since 1.9) is that hashes remain in original insertion order, so that is the case here as well.
    # TODO: Some thought should be given to merging comments, but it's difficult as some people seem to translate them..?
    def deep_merge!(properties)
      properties.each_value do |entry|
        existing_entry = self[entry.key]
        if existing_entry
          existing_entry.value = entry.value
        else # no existing entry, add to the end
          self[entry.key] = entry
        end
      end
    end

    # For passing a Properties to another Properties
    def to_hash; @hash; end

    # Delegating hash-like operations to the hash
    def keys; @hash.keys; end
    def each_pair(&block); @hash.each_pair(&block); end
    def each_key(&block); @hash.each_key(&block); end
    def each_value(&block); @hash.each_value(&block); end
    def merge(hash); Properties.new(@hash.merge(hash)); end
    def merge!(hash); @hash.merge!(hash); end
    def delete_if(&block); @hash.delete_if(&block); end
    def keep_if(&block); @hash.keep_if(&block); end
    def [](key); @hash[key]; end
    def []=(key, value); @hash[key] = value; end
    def key?(key); @hash.key?(key); end
  end

  # Holds rules for how to format files.
  module PropertiesFormat
    def self.escape_key(str, native)
      esc = ''
      str.each_char do |ch|
        esc +=
          case ch
          when ':'
            '\:'
          when '='
            '\='
          when ' '
            '\ '
          else
            value_char_escape(ch, native)
          end
      end
      esc
    end

    def self.escape_value(str, native)
      esc = ''
      str.each_char do |ch|
        esc += value_char_escape(ch, native)
      end
      esc
    end

    def self.value_char_escape(ch, native)
      if ch.ord > 65535
        if native
          ch
        else
          # U+10099 => \uD800\uDC99
          surrogates = ch.encode('UTF-16BE').unpack('n*')
          self.u_escape(surrogates[0]) + self.u_escape(surrogates[1])
        end
      elsif ch.ord > 127
        if native
          ch
        else
          self.u_escape(ch.ord)
        end
      else
        case ch
        when '\\'
          '\\\\'
        when "\r"
          '\r'
        when "\n"
          '\n'
        when "\f"
          '\f'
        when "\t"
          '\t'
        else
          ch
        end
      end 
    end

    def self.u_escape(ord)
      "\\u%04X" % ord
    end

    def self.unescape(str)
      unesc = ''
      in_escape_sequence = false
      in_unicode_sequence = false
      unicode_sequence = ''
      str.each_char do |ch|
        if in_unicode_sequence
          #TODO: I'm pretty sure this won't handle surrogates correctly.
          unicode_sequence += ch
          if unicode_sequence.size == 4
            unesc += [unicode_sequence.to_i(16)].pack("U")
            in_unicode_sequence = false
            in_escape_sequence = false
            unicode_sequence = ''
          end
        elsif in_escape_sequence
          if ch == 'u'
            # \uXXXX is a multi-char sequence (the only one) so we need to handle it specially
            # as it's the only sequence which doesn't require appending something right now.
            in_unicode_sequence = true
          else
            # Every other one terminates the sequence.
            unesc +=
              case ch
              when 'r'
                "\r"
              when 'n'
                "\n"
              when 'f'
                "\f"
              when 't'
                "\t"
              when '\\', ' ', '=', ':',      # These are explicitly documented.
                   '!', '#', '"', "'"        # These are commonly seen but generally don't seem to be a problem.
                ch
              else
                # It is valid to have anything after the escape but this can often point to errors in the files:
                $stderr.puts("WARN: Unnecessary escape in string: `#{str}`")
                ch
              end

            in_escape_sequence = false
          end
        else
          if ch == "\\"
            in_escape_sequence = true
          else
            unesc += ch
          end
        end
      end
      unesc
    end

  end
end
