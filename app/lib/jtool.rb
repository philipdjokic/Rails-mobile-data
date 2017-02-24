# wrapper class around using the jtool command line utility
# http://newosxbook.com/tools/jtool.html
# Assumes running in a Linux environment for utilities
class Jtool

  attr_writer :jtool_exec, :timeout_exec

  def jtool_exec
    @jtool_exec || 'jtool' # should be in PATH
  end

  def timeout_exec
    @timeout_exec || 'timeout'
  end

  def run_command(*args)
    # all binaries are using arm64 and above
    `#{timeout_exec} 30s #{jtool_exec} -arch arm64 #{args.join(' ')}`
  end

  def objc_classes(filepath)
    run_command('-d', 'objc', filepath).split(/\n/).reject { |c| %r{^//}.match(c) }.uniq
  end

  def shared_libraries(filepath)
    run_command('-L', filepath).split(/\n/).map { |l| l.gsub(/^\t/, '') }
  end
end