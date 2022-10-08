class Podman < Formula
  desc "Tool for managing OCI containers and pods"
  homepage "https://podman.io/"
  url "https://github.com/containers/podman/archive/v4.2.1.tar.gz"
  sha256 "b10004e91a9f5528da450466ec8e6f623eaa28ada79e3044c238895b2c8d1df3"
  license all_of: ["Apache-2.0", "GPL-3.0-or-later"]
  head "https://github.com/containers/podman.git", branch: "main"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_monterey: "7a7443b447e60d3f96b523e16f6f87f2ce85373ca8d9225ae21b172fc95a1ea6"
    sha256 cellar: :any_skip_relocation, arm64_big_sur:  "a56477a832e836895b1fa7f9847f80d4c3e55ef4b1409c8d14bee06d8b4c1e4d"
    sha256 cellar: :any_skip_relocation, monterey:       "f5cd5677ba4ff64682eeecb8422ae58bba5327d28480960bc315a6cebea13167"
    sha256 cellar: :any_skip_relocation, big_sur:        "6dd0b75f8496dfe0c3bb618d8194a2ce7e5521881383045385ecbc3225f2e007"
    sha256 cellar: :any_skip_relocation, catalina:       "0f443433962a0fc1555da4e75550aae083075c66c438d38ef98dde1dbeb67eba"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "d64e188e78c05935c6d73713f69ffae54452082e01b9d3f8f7a64c160c302fe9"
  end

  depends_on "go-md2man" => :build

  on_macos do
    # Required latest gvisor.dev/gvisor/pkg/gohacks
    # Try to switch to the latest go on the next release
    depends_on "go@1.18" => :build
    depends_on "qemu"
  end

  on_linux do
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "go" => :build
    depends_on "pkg-config" => :build
    depends_on "rust" => :build
    depends_on "conmon"
    depends_on "crun"
    depends_on "fuse-overlayfs"
    depends_on "gpgme"
    depends_on "libseccomp"
    depends_on "slirp4netns"
    depends_on "systemd"
  end

  resource "gvproxy" do
    on_macos do
      url "https://github.com/containers/gvisor-tap-vsock/archive/v0.4.0.tar.gz"
      sha256 "896cf02fbabce9583a1bba21e2b384015c0104d634a73a16d2f44552cf84d972"
    end
  end

  resource "catatonit" do
    on_linux do
      url "https://github.com/openSUSE/catatonit/archive/refs/tags/v0.1.7.tar.gz"
      sha256 "e22bc72ebc23762dad8f5d2ed9d5ab1aaad567bdd54422f1d1da775277a93296"

      # Fix autogen.sh. Delete on next catatonit release.
      patch do
        url "https://github.com/openSUSE/catatonit/commit/99bb9048f532257f3a2c3856cfa19fe957ab6cec.patch?full_index=1"
        sha256 "cc0828569e930ae648e53b647a7d779b1363bbb9dcbd8852eb1cd02279cdbe6c"
      end
    end
  end

  resource "netavark" do
    on_linux do
      url "https://github.com/containers/netavark/archive/refs/tags/v1.2.0.tar.gz"
      sha256 "35b710197f321a2e45c59460fd8faf67b7b8ebc345d22aa8ecccf806790c6edc"
    end
  end

  resource "aardvark-dns" do
    on_linux do
      url "https://github.com/containers/aardvark-dns/archive/refs/tags/v1.2.0.tar.gz"
      sha256 "434163027660feebb87e288d9c9f8468a1a9d1a632d1f9fe0a84585dfde3f4dd"
    end
  end

  # Allow specifying helper dirs with $BINDIR as base directory. Use a `$BINDIR` magic
  # token as a prefix in the helper path to indicate it should be relative to the
  # directory where the binary is located.
  # This patch can be dropped on upgrade to podman 4.3.0.
  patch do
    on_macos do
      url "https://github.com/containers/common/commit/030b7518103cfd7b930b54744d4a4510b659fdc2.patch?full_index=1"
      sha256 "7c00abe7728d6438abcdb69ce6efa43503dcbb93bcb2d737f6ca4aa553e2eeb5"
      directory "vendor/github.com/containers/common"
    end
  end

  # Update Darwin config to include '$BINDIR/../libexec/podman' in helper search path.
  # This patch can be dropped on upgrade to podman 4.3.0.
  patch do
    on_macos do
      url "https://github.com/containers/common/commit/4e6828877b0067557b435ec8810bda7f5cb48a4f.patch?full_index=1"
      sha256 "01c4c67159f83f636a7b3a6007a010b1336c83246e4fb8c34b67be32fd6c2206"
      directory "vendor/github.com/containers/common"
    end
  end

  # Fix conmon PATH on Linux. Remove on next release.
  patch :DATA

  def install
    if OS.mac?
      ENV["CGO_ENABLED"] = "1"

      system "make", "podman-remote"
      bin.install "bin/darwin/podman" => "podman-remote"
      bin.install_symlink bin/"podman-remote" => "podman"

      system "make", "podman-mac-helper"
      bin.install "bin/darwin/podman-mac-helper" => "podman-mac-helper"

      resource("gvproxy").stage do
        system "make", "gvproxy"
        (libexec/"podman").install "bin/gvproxy"
      end

      system "make", "podman-remote-darwin-docs"
      man1.install Dir["docs/build/remote/darwin/*.1"]

      bash_completion.install "completions/bash/podman"
      zsh_completion.install "completions/zsh/_podman"
      fish_completion.install "completions/fish/podman.fish"
    else
      paths = Dir["**/*.go"].select do |file|
        (buildpath/file).read.lines.grep(%r{/etc/containers/}).any?
      end
      inreplace paths, "/etc/containers/", etc/"containers/"

      ENV.O0
      ENV["PREFIX"] = prefix
      ENV["HELPER_BINARIES_DIR"] = opt_libexec/"podman"

      system "make"
      system "make", "install", "install.completions"

      (prefix/"etc/containers/policy.json").write <<~EOS
        {"default":[{"type":"insecureAcceptAnything"}]}
      EOS

      (prefix/"etc/containers/storage.conf").write <<~EOS
        [storage]
        driver="overlay"
      EOS

      (prefix/"etc/containers/registries.conf").write <<~EOS
        unqualified-search-registries=["docker.io"]
      EOS

      resource("catatonit").stage do
        system "./autogen.sh"
        system "./configure"
        system "make"
        mv "catatonit", libexec/"podman/"
      end

      resource("netavark").stage do
        system "cargo", "install", *std_cargo_args
        mv bin/"netavark", libexec/"podman/"
      end

      resource("aardvark-dns").stage do
        system "cargo", "install", *std_cargo_args
        mv bin/"aardvark-dns", libexec/"podman/"
      end
    end
  end

  def caveats
    on_linux do
      <<~EOS
        You need "newuidmap" and "newgidmap" binaries installed system-wide
        for rootless containers to work properly.
      EOS
    end
  end

  service do
    run [opt_bin/"podman", "system", "service", "--time=0"]
    environment_variables PATH: std_service_path_env
    working_dir HOMEBREW_PREFIX
  end

  test do
    assert_match "podman-remote version #{version}", shell_output("#{bin}/podman-remote -v")
    out = shell_output("#{bin}/podman-remote info 2>&1", 125)
    assert_match "Cannot connect to Podman", out

    if OS.mac?
      out = shell_output("#{bin}/podman-remote machine init --image-path fake-testi123 fake-testvm 2>&1", 125)
      assert_match "Error: open fake-testi123: no such file or directory", out
    else
      assert_equal %W[
        #{bin}/podman
        #{bin}/podman-remote
      ].sort, Dir[bin/"*"].sort
      assert_equal %W[
        #{libexec}/podman/catatonit
        #{libexec}/podman/netavark
        #{libexec}/podman/aardvark-dns
        #{libexec}/podman/rootlessport
      ].sort, Dir[libexec/"podman/*"].sort
      out = shell_output("file #{libexec}/podman/catatonit")
      assert_match "statically linked", out
    end
  end
end
__END__
diff --git a/libpod/oci_conmon_linux.go b/libpod/oci_conmon_linux.go
index c3725cdb46788837f692371802ad1cc2392c8fb7..2c7c39726568d7dccc50f707b53074c3dd4448c6 100644
--- a/libpod/oci_conmon_linux.go
+++ b/libpod/oci_conmon_linux.go
@@ -1221,10 +1221,15 @@ func (r *ConmonOCIRuntime) configureConmonEnv(runtimeDir string) []string {
 			env = append(env, e)
 		}
 	}
-	conf, ok := os.LookupEnv("CONTAINERS_CONF")
-	if ok {
+	if path, ok := os.LookupEnv("PATH"); ok {
+		env = append(env, fmt.Sprintf("PATH=%s", path))
+	}
+	if conf, ok := os.LookupEnv("CONTAINERS_CONF"); ok {
 		env = append(env, fmt.Sprintf("CONTAINERS_CONF=%s", conf))
 	}
+	if conf, ok := os.LookupEnv("CONTAINERS_HELPER_BINARY_DIR"); ok {
+		env = append(env, fmt.Sprintf("CONTAINERS_HELPER_BINARY_DIR=%s", conf))
+	}
 	env = append(env, fmt.Sprintf("XDG_RUNTIME_DIR=%s", runtimeDir))
 	env = append(env, fmt.Sprintf("_CONTAINERS_USERNS_CONFIGURED=%s", os.Getenv("_CONTAINERS_USERNS_CONFIGURED")))
 	env = append(env, fmt.Sprintf("_CONTAINERS_ROOTLESS_UID=%s", os.Getenv("_CONTAINERS_ROOTLESS_UID")))
