#!/usr/bin/ruby
# SyncWatch by loganlinn
# rsyncs filesystem changes

require 'rubygems'
require 'rb-fsevent'

class SyncWatch
  VERSION = [0, 2, 0]

  def initialize(params)
    @path              = params[:path]              || Dir.pwd
    @remote_path       = params[:remote_path]       || Dir.pwd
    @ignore_rules    ||= params[:ignore_rules]      || [/^\.git/, /^\.svn/, /\.DS_Store/]
    @use_notifications = params[:use_notifications] || true
    @verbose           = params[:verbose]           || true
    @growl_password    = params[:growl_password]    || ''

    @last_touched_dirs = nil

    if @use_notifications
      require 'ruby-growl'
    end

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

    if @use_notifications
      @growl = Growl.new "127.0.0.1", @remote_path.split(':').first, ["sync complete"], nil, @growl_password
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
    start = Time.now
    print "\tSyncing..." if @verbose
    %x[rsync -avPz --delete #{@rsync_excludes} -e ssh #{@path} #{@remote_path}]
    duration = '%.2f' % (Time.now - start)
    msg = "rsync complete (took #{duration}s)"
    puts msg if @verbose
    @growl.notify('sync complete', '', msg) if @use_notifications
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
  :use_notifications => false
}

OptionParser.new do |opts|
  opts.banner = "Usage: syncwatch [otpions] <local path> <remote path>"

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    options[:verbose] = v
  end

  opts.on('-X', '--exclude=FILE', 'Exclude file from sync') do |x|
    options[:rsync_excludes] << x
  end

  opts.on('-g', '--use-growl [PASSWORD]', 'Enable Growl notifications') do |p|
    options[:use_notifications] = true
    options[:growl_password]    = p
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
