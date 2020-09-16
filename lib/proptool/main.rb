require 'proptool/properties'
require 'proptool/merge_command'
require 'proptool/normalise_command'
require 'proptool/prepare_job_command'
require 'proptool/split_command'

module PropTool
  class Main

    def usage
      $stderr.puts(<<EOF)
usage: #{$0} split [--locales=<loc>[,<loc>...]]
                   [--include=<pathglob> ...]
                   [--exclude=<pathglob> ...]
                   <srcdir> <destdir>
       #{$0} prepare-job --locales=<loc>[,<loc>...]
                         [--include=<pathglob> ...]
                         [--exclude=<pathglob> ...]
                         <srcdir> <destdir>
       #{$0} merge [--source-encoding=<encoding>] <srcdir> <destdir>
       #{$0} normalise <dir>
EOF
    end

    def run(args)
      if ARGV.size < 1
        usage
        exit 1
      end

      begin
        command = args.shift
        case command
        when 'split'
          PropTool::SplitCommand.new.run(*args)
        when 'prepare-job'
          PropTool::PrepareJobCommand.new.run(*args)
        when 'merge'
          PropTool::MergeCommand.new.run(*args)
        when 'normalise', 'normalize'
          PropTool::NormaliseCommand.new.run(*args)
        else
          $stderr.puts("Unrecognised command: #{command}")
          usage
          exit 1
        end
      rescue Interrupt
        $stderr.puts('Interrupted.')
        exit 1
      end
    end

  end
end