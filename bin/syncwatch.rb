#!/usr/bin/env ruby
# SyncWatch by loganlinn
# rsyncs filesystem changes

require 'rb-fsevent'

class SyncWatch
  VERSION = [0, 2, 0]

  def initialize(params)
    @path              = params[:path]              || Dir.pwd
    @remote_path       = params[:remote_path]       || Dir.pwd
    @ignore_rules    ||= params[:ignore_rules]      || [/^\.git/, /^\.svn/, /\.DS_Store/]
    @verbose           = params[:verbose]           || true
    @port              = params[:port]

    @last_touched_dirs = nil

    @rsync_excludes = if params[:rsync_excludes].nil?
                        ''
                      else
                        params[:rsync_excludes].reduce('') {|list, excl| list += "--exclude=#{excl} "}
                      end

    @fsevent = FSEvent.new

    ## trigger event
    @fsevent.watch @path do |dirs|
      @last_touched_dirs = dirs
      puts "[#{Time.now.to_s}] Detected #{dirs.length} change#{'s' if dirs.length > 1}" if @verbose

      if requires_sync? dirs
        run_sync
      else
        puts "\tOnly ignored files changed -- skipping sync" if @verbose
      end
    end
  end

  def requires_sync? (dirs)
    # run through directories. sync if 1+ non-ignored files change
    dirs.each do |dir|
      dir.gsub!(@path, '') # normalize
      return true unless dir_ignored? dir  #only need 1 non-ignore to run the syncd
    end
    false
  end

  def run_sync
    print "\tSyncing..." if @verbose
    start = Time.now
    rsh = 'ssh'
    rsh += " -p#{@port}" unless @port.nil?
    %x[rsync -avPz --delete #{@rsync_excludes} --rsh='#{rsh}' #{@path} #{@remote_path} ]
    msg = "rsync complete (took %.2fs)" % (Time.now - start)
    puts msg if @verbose
  end

  def run
    if @verbose
      puts '==  Starting SyncWatch =='
      puts "[#{@path}]=>[#{@remote_path}]"
      puts 'Initial Sync:'
    end
    run_sync
    @fsevent.run
  end

  def dir_ignored?(dir)
    @ignore_rules.reduce(false) {|v,r| break(true) if dir =~ r }
  end
end

#=====
require 'optparse'

# Default options
options = {
  :rsync_excludes          => [],
}

OptionParser.new do |opts|
  opts.banner = "Usage: syncwatch [otpions] <local path> <remote path>"

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    options[:verbose] = v
  end

  opts.on('-X', '--exclude=FILE', 'Exclude file from sync') do |x|
    options[:rsync_excludes] << x
  end

  opts.on('-p', '--port [PORT]', 'Port to SSH to on remote host') do |p|
    options[:port] = p
  end

  opts.on_tail('--version', 'Show version') do
    puts SyncWatch::VERSION.join('.')
    exit
  end

end.parse!

options[:path]        = ARGV[0]
options[:remote_path] = ARGV[1]

# Error checking
if options[:path].nil?
  $stderr.puts "Local path not provided"
  exit
elsif options[:remote_path].nil?
  $stderr.puts "Remote path not provided"
  exit
end

unless File.directory? options[:path]
  $stderr.puts "Invalid path specified"
  exit
end

# Start
sw = SyncWatch.new options
sw.run
