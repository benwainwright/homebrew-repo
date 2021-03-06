require "language/node"

class ClientCertProxy < Formula
  version "1.0.0"
  desc "Proxies requests, providing client side certificates"
  homepage "https://github.com/kieran-bamforth/client-cert-proxy"
  url "https://github.com/kieran-bamforth/client-cert-proxy/archive/1.0.0.tar.gz"
  sha256 "61930a62d3de07348f2400bf47e4048d171f60a9f55beea53a71b7a11c2fdbf3"

  plist_options :startup => true

  depends_on "node"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>#{plist_name}</string>
            <key>ProgramArguments</key>
            <array>
                <string>/usr/local/bin/node</string>
                <string>#{opt_bin}/client-cert-proxy</string>
            </array>
            <key>EnvironmentVariables</key>
            <dict>
                <key>PROXY_PATH</key>
                <string>#{var}/client-cert-proxy.sock</string>
                <key>TARGET</key>
                <string>https://jira.dev.bbc.co.uk</string>
                <key>CERT</key>
                <string>/etc/pki/tls/certs/client.crt</string>
                <key>KEY</key>
                <string>/etc/pki/tls/private/client.key</string>
            </dict>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardErrorPath</key>
            <string>/tmp/out.err</string>
            <key>StandardOutPath</key>
            <string>/tmp/out.log</string>
        </dict>
    </plist>
    EOS
  end

  def install
    system "npm", "install", *Language::Node.std_npm_install_args(libexec)
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

end
