class Lua < Formula
    desc "Powerful, lightweight programming language"
    homepage "https://www.lua.org/"
    url "https://www.lua.org/ftp/lua-5.2.4.tar.gz"
    sha256 "b9e2e4aad6789b3b63a056d442f7b39f0ecfca3ae0f1fc0ae4e9614401b69f4b"
    revision 5

    # Be sure to build a dylib, or else runtime modules will pull in another static copy of liblua = crashy
    # See: https://github.com/Homebrew/legacy-homebrew/pull/5043
    patch :DATA

    # Don't use the https://luarocks.org/releases/luarocks-x.y.z.tar.gz URL
    # directly as it redirects to the HTTP version of the below URL.
    resource "luarocks" do
        url "https://luarocks.github.io/luarocks/releases/luarocks-2.4.3.tar.gz"
        sha256 "4d414d32fed5bb121c72d3ff1280b7f2dc9027a9bc012e41dfbffd5b519b362e"
    end

    def install
        # Subtitute formula prefix in `src/Makefile` for install name (dylib ID).
        # Use our CC/CFLAGS to compile.
        inreplace "src/Makefile" do |s|
            s.gsub! "@LUA_PREFIX@", prefix
            s.remove_make_var! "CC"
            s.change_make_var! "CFLAGS", "#{ENV.cflags} -DLUA_COMPAT_ALL $(SYSCFLAGS) $(MYCFLAGS)"
            s.change_make_var! "MYLDFLAGS", ENV.ldflags
        end

        # Fix path in the config header
        inreplace "src/luaconf.h", "/usr/local", HOMEBREW_PREFIX

        # We ship our own pkg-config file as Lua no longer provide them upstream.
        system "make", "macosx", "INSTALL_TOP=#{prefix}", "INSTALL_MAN=#{man1}"
        system "make", "install", "INSTALL_TOP=#{prefix}", "INSTALL_MAN=#{man1}"
        (lib/"pkgconfig/lua.pc").write pc_file

        # Fix some software potentially hunting for different pc names.
        bin.install_symlink "lua" => "lua5.2"
        bin.install_symlink "lua" => "lua-5.2"
        bin.install_symlink "luac" => "luac5.2"
        bin.install_symlink "luac" => "luac-5.2"
        (include/"lua5.2").install_symlink include.children
        (lib/"pkgconfig").install_symlink "lua.pc" => "lua5.2.pc"
        (lib/"pkgconfig").install_symlink "lua.pc" => "lua-5.2.pc"

        # This resource must be handled after the main install, since there's a lua dep.
        # Keeping it in install rather than postinstall means we can bottle.
        resource("luarocks").stage do
            ENV.prepend_path "PATH", bin

            system "./configure", "--prefix=#{libexec}", "--rocks-tree=#{HOMEBREW_PREFIX}",
                "--sysconfdir=#{etc}/luarocks52", "--with-lua=#{prefix}",
                "--lua-version=5.2", "--versioned-rocks-dir"
                system "make", "build"
                system "make", "install"

                (pkgshare/"5.2/luarocks").install_symlink Dir["#{libexec}/share/lua/5.2/luarocks/*"]
                bin.install_symlink libexec/"bin/luarocks-5.2"
                bin.install_symlink libexec/"bin/luarocks-admin-5.2"
                bin.install_symlink libexec/"bin/luarocks"
                bin.install_symlink libexec/"bin/luarocks-admin"

                # This block ensures luarock exec scripts don't break across updates.
                inreplace libexec/"share/lua/5.2/luarocks/site_config.lua" do |s|
                    s.gsub! libexec.to_s, opt_libexec
                    s.gsub! include.to_s, "#{HOMEBREW_PREFIX}/include"
                    s.gsub! lib.to_s, "#{HOMEBREW_PREFIX}/lib"
                    s.gsub! bin.to_s, "#{HOMEBREW_PREFIX}/bin"
                end
        end
    end

    def pc_file; <<~EOS
    V= 5.2
    R= 5.2.4
    prefix=#{opt_prefix}
    INSTALL_BIN= ${prefix}/bin
    INSTALL_INC= ${prefix}/include
    INSTALL_LIB= ${prefix}/lib
    INSTALL_MAN= ${prefix}/share/man/man1
    INSTALL_LMOD= #{HOMEBREW_PREFIX}/share/lua/${V}
    INSTALL_CMOD= #{HOMEBREW_PREFIX}/lib/lua/${V}
    exec_prefix=${prefix}
    libdir=${exec_prefix}/lib
    includedir=${prefix}/include

    Name: Lua
    Description: An Extensible Extension Language
    Version: 5.2.4
    Requires:
    Libs: -L${libdir} -llua -lm
    Cflags: -I${includedir}
        EOS
    end

    def caveats; <<~EOS
    Please be aware due to the way Luarocks is designed any binaries installed
    via Luarocks-5.2 AND 5.1 will overwrite each other in #{HOMEBREW_PREFIX}/bin.

    This is, for now, unavoidable. If this is troublesome for you, you can build
    rocks with the `--tree=` command to a special, non-conflicting location and
    then add that to your `$PATH`.
        EOS
    end

    test do
        system "#{bin}/lua", "-e", "print ('Ducks are cool')"

        if File.exist?(bin/"luarocks-5.2")
            (testpath/"luarocks").mkpath
            system bin/"luarocks-5.2", "install", "moonscript", "--tree=#{testpath}/luarocks"
            assert_predicate testpath/"luarocks/bin/moon", :exist?
        end
    end
end

__END__
diff --git a/Makefile b/Makefile
index bd9515f..5940ba9 100644
--- a/Makefile
+++ b/Makefile
@@ -41,7 +41,7 @@ PLATS= aix ansi bsd freebsd generic linux macosx mingw posix solaris
 # What to install.
 TO_BIN= lua luac
 TO_INC= lua.h luaconf.h lualib.h lauxlib.h lua.hpp
-TO_LIB= liblua.a
+TO_LIB= liblua.5.2.4.dylib
 TO_MAN= lua.1 luac.1

 # Lua version and release.
@@ -63,6 +63,8 @@ install: dummy
	cd src && $(INSTALL_DATA) $(TO_INC) $(INSTALL_INC)
	cd src && $(INSTALL_DATA) $(TO_LIB) $(INSTALL_LIB)
	cd doc && $(INSTALL_DATA) $(TO_MAN) $(INSTALL_MAN)
+	ln -s -f liblua.5.2.4.dylib $(INSTALL_LIB)/liblua.5.2.dylib
+	ln -s -f liblua.5.2.dylib $(INSTALL_LIB)/liblua.dylib

 uninstall:
	cd src && cd $(INSTALL_BIN) && $(RM) $(TO_BIN)
diff --git a/src/Makefile b/src/Makefile
index 8c9ee67..7f92407 100644
--- a/src/Makefile
+++ b/src/Makefile
@@ -28,7 +28,7 @@ MYOBJS=

 PLATS= aix ansi bsd freebsd generic linux macosx mingw posix solaris

-LUA_A=	liblua.a
+LUA_A=	liblua.5.2.4.dylib
 CORE_O=	lapi.o lcode.o lctype.o ldebug.o ldo.o ldump.o lfunc.o lgc.o llex.o \
	lmem.o lobject.o lopcodes.o lparser.o lstate.o lstring.o ltable.o \
	ltm.o lundump.o lvm.o lzio.o
@@ -56,11 +56,12 @@ o:	$(ALL_O)
 a:	$(ALL_A)

 $(LUA_A): $(BASE_O)
-	$(AR) $@ $(BASE_O)
-	$(RANLIB) $@
+	$(CC) -dynamiclib -install_name @LUA_PREFIX@/lib/liblua.5.2.dylib \
+		-compatibility_version 5.2 -current_version 5.2.4 \
+		-o liblua.5.2.4.dylib $^

 $(LUA_T): $(LUA_O) $(LUA_A)
-	$(CC) -o $@ $(LDFLAGS) $(LUA_O) $(LUA_A) $(LIBS)
+	$(CC) -fno-common $(MYLDFLAGS) -o $@ $(LUA_O) $(LUA_A) -L. -llua.5.2.4 $(LIBS)

 $(LUAC_T): $(LUAC_O) $(LUA_A)
	$(CC) -o $@ $(LDFLAGS) $(LUAC_O) $(LUA_A) $(LIBS)
@@ -106,7 +107,7 @@ linux:
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_LINUX" SYSLIBS="-Wl,-E -ldl -lreadline"

 macosx:
-	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX" SYSLIBS="-lreadline" CC=cc
+	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX -fno-common" SYSLIBS="-lreadline" CC=cc

 mingw:
	$(MAKE) "LUA_A=lua52.dll" "LUA_T=lua.exe" \
