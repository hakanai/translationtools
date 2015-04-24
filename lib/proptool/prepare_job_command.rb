module PropTool
  class PrepareJobCommand
    # args[0] - root of source directory
    # args[1] - root of destination directory
    def run(*args)
      srcdirstr = nil
      dstdirstr = nil

      locales = []
      excludes = []
      dstopts = {}

      #TODO proper usage errors which can be caught to display the usual usage message
      #TODO proper option parser?
      until args.empty?
        arg = args.shift
        if arg =~ /^--locales=(.*)$/
          locales = $1.split(',')
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

      Pathname.glob("#{srcdir}/**/*.properties") do |srcfile|
        # Because srcdir could be . and dealing with ./* paths is a hassle.
        srcfile = srcfile.cleanpath

        next if excludes.any?{ |glob| srcfile.fnmatch?(glob) }

        srcpath = srcfile.relative_path_from(srcdir)
        if srcpath.to_s =~ /^([^_]*?)(.properties)$/
          locales.each do |locale|
            dstpath = "#{$1}_#{locale}#{$2}"
            localised_srcfile = srcdir.join(dstpath)
            dstfile = dstdir.join(locale).join(dstpath)
            FileUtils.mkdir_p(dstfile.parent)

            properties = Properties.load(srcfile)

            # Removing any string which is already translated.
            if localised_srcfile.exist?
              translated = Properties.load(localised_srcfile)
              properties.delete_if { |key, value| translated.key?(key) }
            end

            properties.store(dstfile)
          end
        end
      end
    end
  end
end
