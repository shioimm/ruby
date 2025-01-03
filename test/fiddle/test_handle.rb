# frozen_string_literal: true
begin
  require_relative 'helper'
rescue LoadError
end

module Fiddle
  class TestHandle < TestCase
    include Fiddle

    def test_library_unavailable
      assert_raise(DLError) do
        Fiddle::Handle.new("does-not-exist-library")
      end
      assert_raise(DLError) do
        Fiddle::Handle.new("/does/not/exist/library.#{RbConfig::CONFIG['SOEXT']}")
      end
    end

    def test_to_i
      if ffi_backend?
        omit("Fiddle::Handle#to_i is unavailable with FFI backend")
      end

      handle = Fiddle::Handle.new(LIBC_SO)
      assert_kind_of Integer, handle.to_i
    end

    def test_to_ptr
      if ffi_backend?
        omit("Fiddle::Handle#to_i is unavailable with FFI backend")
      end

      handle = Fiddle::Handle.new(LIBC_SO)
      ptr = handle.to_ptr
      assert_equal ptr.to_i, handle.to_i
    end

    def test_static_sym_unknown
      assert_raise(DLError) { Fiddle::Handle.sym('fooo') }
      assert_raise(DLError) { Fiddle::Handle['fooo'] }
      refute Fiddle::Handle.sym_defined?('fooo')
    end

    def test_static_sym
      if ffi_backend?
        omit("We can't assume static symbols with FFI backend")
      end

      begin
        # Linux / Darwin / FreeBSD
        refute_nil Fiddle::Handle.sym('dlopen')
        assert Fiddle::Handle.sym_defined?('dlopen')
        assert_equal Fiddle::Handle.sym('dlopen'), Fiddle::Handle['dlopen']
        return
      rescue
      end

      begin
        # NetBSD
        require '-test-/dln/empty'
        refute_nil Fiddle::Handle.sym('Init_empty')
        assert_equal Fiddle::Handle.sym('Init_empty'), Fiddle::Handle['Init_empty']
        return
      rescue
      end
    end unless /mswin|mingw/ =~ RUBY_PLATFORM

    def test_sym_closed_handle
      handle = Fiddle::Handle.new(LIBC_SO)
      handle.close
      assert_raise(DLError) { handle.sym("calloc") }
      assert_raise(DLError) { handle["calloc"] }
    end

    def test_sym_unknown
      handle = Fiddle::Handle.new(LIBC_SO)
      assert_raise(DLError) { handle.sym('fooo') }
      assert_raise(DLError) { handle['fooo'] }
      refute handle.sym_defined?('fooo')
    end

    def test_sym_with_bad_args
      handle = Handle.new(LIBC_SO)
      assert_raise(TypeError) { handle.sym(nil) }
      assert_raise(TypeError) { handle[nil] }
    end

    def test_sym
      handle = Handle.new(LIBC_SO)
      refute_nil handle.sym('calloc')
      refute_nil handle['calloc']
      assert handle.sym_defined?('calloc')
    end

    def test_handle_close
      handle = Handle.new(LIBC_SO)
      assert_equal 0, handle.close
    end

    def test_handle_close_twice
      handle = Handle.new(LIBC_SO)
      handle.close
      assert_raise(DLError) do
        handle.close
      end
    end

    def test_dlopen_returns_handle
      assert_instance_of Handle, dlopen(LIBC_SO)
    end

    def test_initialize_noargs
      if RUBY_ENGINE == "jruby"
        omit("rb_str_new() doesn't exist in JRuby")
      end

      handle = Handle.new
      refute_nil handle['rb_str_new']
    end

    def test_initialize_flags
      handle = Handle.new(LIBC_SO, RTLD_LAZY | RTLD_GLOBAL)
      refute_nil handle['calloc']
    end

    def test_enable_close
      handle = Handle.new(LIBC_SO)
      assert !handle.close_enabled?, 'close is enabled'

      handle.enable_close
      assert handle.close_enabled?, 'close is not enabled'
    end

    def test_disable_close
      handle = Handle.new(LIBC_SO)

      handle.enable_close
      assert handle.close_enabled?, 'close is enabled'
      handle.disable_close
      assert !handle.close_enabled?, 'close is enabled'
    end

    def test_file_name
      if ffi_backend?
        omit("Fiddle::Handle#file_name doesn't exist in FFI backend")
      end

      file_name = Handle.new(LIBC_SO).file_name
      if file_name
        assert_kind_of String, file_name
        expected = [File.basename(LIBC_SO)]
        begin
          expected << File.basename(File.realpath(LIBC_SO, File.dirname(file_name)))
        rescue Errno::ENOENT
        end
        basename = File.basename(file_name)
        unless File::FNM_SYSCASE.zero?
          basename.downcase!
          expected.each(&:downcase!)
        end
        assert_include expected, basename
      end
    end

    def test_NEXT
      if ffi_backend?
        omit("Fiddle::Handle::NEXT doesn't exist in FFI backend")
      end

      begin
        # Linux / Darwin
        #
        # There are two special pseudo-handles, RTLD_DEFAULT and RTLD_NEXT.  The  former  will  find
        # the  first  occurrence  of the desired symbol using the default library search order.  The
        # latter will find the next occurrence of a function in the search order after  the  current
        # library.   This  allows  one  to  provide  a  wrapper  around a function in another shared
        # library.
        # --- Ubuntu Linux 8.04 dlsym(3)
        handle = Handle::NEXT
        refute_nil handle['malloc']
        return
      rescue
      end

      begin
        # BSD
        #
        # If dlsym() is called with the special handle RTLD_NEXT, then the search
        # for the symbol is limited to the shared objects which were loaded after
        # the one issuing the call to dlsym().  Thus, if the function is called
        # from the main program, all the shared libraries are searched.  If it is
        # called from a shared library, all subsequent shared libraries are
        # searched.  RTLD_NEXT is useful for implementing wrappers around library
        # functions.  For example, a wrapper function getpid() could access the
        # "real" getpid() with dlsym(RTLD_NEXT, "getpid").  (Actually, the dlfunc()
        # interface, below, should be used, since getpid() is a function and not a
        # data object.)
        # --- FreeBSD 8.0 dlsym(3)
        require '-test-/dln/empty'
        handle = Handle::NEXT
        refute_nil handle['Init_empty']
        return
      rescue
      end
    end unless /mswin|mingw/ =~ RUBY_PLATFORM

    def test_DEFAULT
      if Fiddle::WINDOWS
        omit("Fiddle::Handle::DEFAULT doesn't have malloc() on Windows")
      end

      handle = Handle::DEFAULT
      refute_nil handle['malloc']
    end

    def test_dlerror
      # FreeBSD (at least 7.2 to 7.2) calls nsdispatch(3) when it calls
      # getaddrinfo(3). And nsdispatch(3) doesn't call dlerror(3) even if
      # it calls _nss_cache_cycle_prevention_function with dlsym(3).
      # So our Fiddle::Handle#sym must call dlerror(3) before call dlsym.
      # In general uses of dlerror(3) should call it before use it.
      verbose, $VERBOSE = $VERBOSE, nil
      require 'socket'
      Socket.gethostbyname("localhost")
      Fiddle.dlopen("/lib/libc.so.7").sym('strcpy')
    ensure
      $VERBOSE = verbose
    end if /freebsd/=~ RUBY_PLATFORM

    if /cygwin|mingw|mswin/ =~ RUBY_PLATFORM
      def test_fallback_to_ansi
        k = Fiddle::Handle.new("kernel32.dll")
        ansi = k["GetFileAttributesA"]
        assert_equal(ansi, k["GetFileAttributes"], "should fallback to ANSI version")
      end
    end

    def test_ractor_shareable
      omit("Need Ractor") unless defined?(Ractor)
      assert_ractor_shareable(Fiddle::Handle.new(LIBC_SO))
    end
  end
end if defined?(Fiddle)
