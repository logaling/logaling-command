module Logaling::Command
  # http://nex-3.com/posts/73-git-style-automatic-paging-in-ruby
  module Pager
    def self.run
      return if windows?
      return unless STDOUT.tty?

      read, write = IO.pipe

      unless Kernel.fork # Child process
        STDOUT.reopen(write)
        STDERR.reopen(write) if STDERR.tty?
        read.close
        write.close
        return
      end

      # Parent process, become pager
      STDIN.reopen(read)
      read.close
      write.close

      ENV['LESS'] = 'FSRX' # Don't page if the input is short enough

      # wait until we have input before we start the pager
      Kernel.select [STDIN]
      pager = ENV['PAGER'] || 'less'
      exec pager rescue exec "/bin/sh", "-c", pager
    end

    private
    def self.windows?
      RUBY_PLATFORM =~ /win32|mingw32/i
    end
  end
end
