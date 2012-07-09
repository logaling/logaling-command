# Copyright (C) 2011  Miho SUZUKI
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')
require 'logaling'

require "fileutils"
require 'tmpdir'
require 'stringio'

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

  config.before(:suite) do
    LOGALING_HOME = Dir.mktmpdir
  end

  config.before(:all) do
    @logaling_home = LOGALING_HOME
  end

  config.after(:suite) do
    FileUtils.rm_rf(LOGALING_HOME, :secure => true)
  end

  alias :silence :capture
end
