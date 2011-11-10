$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
require 'logaling'

require "fileutils"
require 'stringio'

LOGALING_HOME = File.expand_path("~/.logaling.d")

RSpec.configure do |config|
  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

  alias :silence :capture
end

