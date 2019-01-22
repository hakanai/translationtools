module PropTool
  class PrepareJobCommand
    # args[0] - root of source directory
    # args[1] - root of destination directory
    def run(*args)
      srcdirstr = nil
      dstdirstr = nil

      locales = []
      includes = []
      excludes = []
      dstopts = {}

      #TODO proper usage errors which can be caught to display the usual usage message
      #TODO proper option parser?
      until args.empty?
        arg = args.shift
        if arg =~ /^--locales=(.*)$/
          locales = $1.split(',')
        elsif arg =~ /^--include=(.*)$/
          includes << $1
        elsif arg =~ /^--exclude=(.*)$/
          excludes << $1
        elsif arg =~ /^--destination-encoding=(.*)$/
          dstopts[:encoding] = $1
        else
          if srcdirstr.nil?
            srcdirstr = arg
          elsif dstdirstr.nil?
            dstdirstr = arg
          else
            raise('too many args')
          end
        end
      end

      raise('--locales not specified or contains no values') if locales.empty?
      raise('srcdir == nil') if srcdirstr.nil?
      raise('dstdir == nil') if dstdirstr.nil?

      srcdir = Pathname.new(srcdirstr)
      dstdir = Pathname.new(dstdirstr)

      statistics = {}

      Pathname.glob("#{srcdir}/**/*.properties") do |srcfile|
        # Because srcdir could be . and dealing with ./* paths is a hassle.
        srcfile = srcfile.cleanpath
        srcpath = srcfile.relative_path_from(srcdir)

        next if excludes.any? { |glob| srcpath.fnmatch?(glob) }
        next if !includes.empty? && !includes.any? { |glob| srcpath.fnmatch?(glob) }

        if srcpath.to_s =~ /^([^_]*?)(.properties)$/
          locales.each do |locale|
            dstpath = "#{$1}_#{locale}#{$2}"
            localised_srcfile = srcdir.join(dstpath)
            dstfile = dstdir.join(locale).join(dstpath)

            properties = Properties.load(srcfile)

            # Removing any string which is already translated.
            if localised_srcfile.exist?
              translated = Properties.load(localised_srcfile)
              properties.delete_if { |key, value| translated.key?(key) }
            end

            if !properties.empty?
              stats = (statistics[locale] ||= Hash.new(0))
              properties.each_pair do |key, value|
                stats[:strings] += 1
                stats[:words] += count_words(value.value)
              end

              FileUtils.mkdir_p(dstfile.parent)
              properties.store(dstfile)
            end
          end
        end
      end

      puts '+--------------------------------------+'
      puts '|  Missing string report               |'
      puts '+--------------+-----------+-----------+'
      puts '|  Locale      |  Strings  |    Words  |'

      statistics.each_pair do |locale, stats|
        puts '+--------------+-----------+-----------+'
        #XXX: Commas would look nicer for the numbers but Ruby appears to lack the ability.
        puts "|  %-10s  |  %7d  |  %7d  |" % [ locale, stats[:strings], stats[:words] ]
      end

      puts '+--------------+-----------+-----------+'

    end

    private

    # Fairly rough word count implementation.
    #
    # @param string [String] the input string.
    # @return [Integer] the number of words in the string.
    def count_words(string)
      string.gsub(/<[^>]+>/, ' ')
            .gsub(/\\W+/, ' ')
            .strip.split(' ').size
    end
  end
end
