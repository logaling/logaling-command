# -*- encoding: utf-8 -*-

require "logaling/command"

module Logaling
  class LogalingError < RuntimeError; end
  class TermError < LogalingError; end
  class CommandFailed < LogalingError; end
  class GlossaryNotFound < LogalingError; end
  class GlossaryDBNotFound < LogalingError; end
end
