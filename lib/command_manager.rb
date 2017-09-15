#------------------------------------------------------------------------------#
# Copyright 2010-2015, OpenNebula Systems                                      #
#                                                                              #
# Licensed under the Apache License, Version 2.0 (the "License"); you may      #
# not use this file except in compliance with the License. You may obtain      #
# a copy of the License at                                                     #
#                                                                              #
# http://www.apache.org/licenses/LICENSE-2.0                                   #
#                                                                              #
# Unless required by applicable law or agreed to in writing, software          #
# distributed under the License is distributed on an "AS IS" BASIS,            #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.     #
# See the License for the specific language governing permissions and          #
# limitations under the License.                                               #
#------------------------------------------------------------------------------#

require 'pp'
require 'open3'
require 'stringio'

# Generic command executor that holds the code shared by all the command
# executors.
#
# Properties:
#
# * +code+: integer holding the exit code. Read-only
# * +stdout+: string of the standard output. Read-only
# * +stderr+: string of the standard error. Read-only
# * +command+: command to execute. Read-only
#
# The protocol for scripts to log is as follows:
#
# * Log messages will be sent to STDOUT
# * The script will return 0 if it succeeded or any other value
#   if there was a failure
# * In case of failure the cause of the error will be written to STDERR
#   wrapped by start and end marks as follows:
#
#     ERROR MESSAGE --8<------
#     error message for the failure
#     ERROR MESSAGE ------>8--


class GenericCommand
    attr_reader :code, :stdout, :stderr, :command

    # Creates a command and runs it
    def self.run(command, stdin=nil)
        cmd = self.new(command, stdin)
        cmd.run
        cmd
    end

    # Creates the new command:
    # +command+: string with the command to be executed
    # +logger+: proc that takes a message parameter and logs it
    def initialize(command, stdin=nil)
        @command = command
        @stdin   = stdin
    end

    # Sends a log message to the logger 
    def log(message)
        File.open("adaptors.log", 'w') { |file| file.write(message) }
    end

    # Runs the command
    def run
        std = execute

        # Close standard IO descriptors
        if @stdin
            std[0] << @stdin
            std[0].flush
        end
        std[0].close if !std[0].closed?

        @stdout=std[1].read
        std[1].close if !std[1].closed?

        @stderr=std[2].read
        std[2].close if !std[2].closed?

        @code=get_exit_code(@stderr)

        if @code!=0
            log("Command execution fail: #{command}")
            log(@stderr)
        end

        return @code
    end

    # Parses error message from +stderr+ output
    def get_error_message
        tmp=@stderr.scan(/^ERROR MESSAGE --8<------\n(.*?)ERROR MESSAGE ------>8--$/m)
        return "-" if !tmp[0]
        tmp[0].join(' ').strip
    end

private

    # Gets exit code from STDERR
    def get_exit_code(str)
        tmp=str.scan(/^ExitCode: (\d*)$/)
        return nil if !tmp[0]
        tmp[0][0].to_i
    end

    # Low level command execution. This method has to be redefined
    # for each kind of command execution. Returns an array with
    # +stdin+, +stdout+ and +stderr+ handlers of the command execution.
    def execute
        puts "About to execute \"#{@command}\""
        [StringIO.new, StringIO.new, StringIO.new]
    end

end

# Executes commands in the machine where it is called. See documentation
# for GenericCommand
class LocalCommand < GenericCommand
private

    def execute
        Open3.popen3("#{command} ; echo ExitCode: $? 1>&2")
    end
end


if $0 == __FILE__

    command=GenericCommand.run("uname -a")
    puts command.stderr

    local_command=LocalCommand.run("uname -a")
    puts "STDOUT:"
    puts local_command.stdout
    puts
    puts "STDERR:"
    puts local_command.stderr
end