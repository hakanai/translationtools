module PropTool
  class Properties

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
        continuation_key = continuation_value = nil
        io.each_line do |line|

          # Converting to UTF-8 eagerly so that output works.
          line.encode!('UTF-8')

          # BOM on front of UTF-8 files is not recommended but some people do it anyway.
          #XXX: Technically this could be restricted to the first line or for Unicode formats only.
          line.sub!(/^\uFEFF/, '')

          line.strip!

          next if line == ''
          next if line =~ /^#/

          # These will be nil for the first line of a property definition.
          key = continuation_key
          value = continuation_value
          continuation = !!(line =~ /\\$/)

          if key
            value += unescape(line)
          else
            #XXX: This only supports = as the separator. Technically the format permits colon or even just space.
            if line =~ /^(.*?)\s*=\s*(.*?)\\?$/
              key, value = unescape($1), unescape($2)
            else
              raise "Not properties format? #{line} (file: #{file})"
            end
          end

          if continuation
            continuation_key = key
            continuation_value = value
          else
            continuation_key = continuation_value = nil
            properties[key] = value
          end
        end
      end
      properties
    end

    # Saves the properties to a file.
    def store(file)
      File.open(file.to_s, 'w:ISO-8859-1') do |io|
        each_pair do |key, value|
          io.write("#{self.class.escape_key(key)}=#{self.class.escape_value(value)}\n")
        end
      end
    end

    # For passing a Properties to another Properties
    def to_hash; @hash; end

    # Delegating hash-like operations to the hash
    def keys; @hash.keys; end
    def each_pair(&block); @hash.each_pair(&block); end
    def merge(hash); Properties.new(@hash.merge(hash)); end
    def merge!(hash); @hash.merge!(hash); end
    def [](key); @hash[key]; end
    def []=(key, value); @hash[key] = value; end

  protected

    def self.escape_key(str)
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
            value_char_escape(ch)
          end
      end
      esc
    end

    def self.escape_value(str)
      esc = ''
      str.each_char do |ch|
        esc += value_char_escape(ch)
      end
      esc
    end

    def self.value_char_escape(ch)
      if ch.ord > 65535
        # U+10099 => \uD800\uDC99
        surrogates = ch.encode('UTF-16BE').unpack('n*')
        self.u_escape(surrogates[0]) + self.u_escape(surrogates[1])
      elsif ch.ord > 127
        self.u_escape(ch.ord)
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
