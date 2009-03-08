require 'rubygems'

begin
  # library for encoding and decoding of bencoded data used in the BitTorrent protocol
  # http://en.wikipedia.org/wiki/Bencode
  # http://www.bittorrent.org/protocol.html
  # http://wiki.theory.org/BitTorrentSpecification
  require 'bencode'
rescue LoadError => bencode_load_err
  puts bencode_load_err
  puts "Please install bencode from http://rubyforge.org/projects/bencode/"
  exit
end

tb = Time.now

APP_AUTH = "Anton Maminov"
APP_NAME = "rbtorstat"
APP_VER = "0.2"

# Absolute path to directory
main_path = File.expand_path(File.dirname(__FILE__))

# HTML Template File
tmpl_file = main_path + '/rbtorstat.tmpl'

status_page = File.readlines(tmpl_file).join

# Double quote escape character
status_page = status_page.gsub('"','\"')

# Apache dir with downloaded torrents
@torrents_dir = "rtorrent/"

def sz(size)
  if size < 1024**2
    return "%0.2f Kb" % (size.to_f/1024)
  elsif size < 1024**3
    return "%0.2f MB" % (size.to_f/1024**2)
  else
    return "%0.2f GB" % (size.to_f/1024**3)
  end
end

def started_stoped(state, complete)
  # current status of process
  return "FINISHED" if complete == 1
  return "STARTED"  if state == 1
  return "STOPED"
end

def ignores(ignores_orders)
  if ignores_orders == 1
    return "IGNORES ORDERS"
  end
  return ""
end

def get_status(torrent)
  file_output = [] # Array for web template?

  t_dict = BEncode.load_file(torrent)
  t_name = t_dict['info']['name'] # the filename of the file. This is purely advisory. (string)
  begin
    t_size = 0
    # a list of dictionaries, one for each file
    t_dict['info']['files'].each{|f| t_size += f['length']}
  rescue => e
    t_size = t_dict['info']['length'] # Single File Mode: length of the file in bytes (integer)
  end
  t_chunk_len = t_dict['info']['piece length'] # number of bytes in each piece (integer)
  total_downloaded = t_dict['rtorrent']['chunks_done'] * t_chunk_len

  total_uploaded = t_dict['rtorrent']['total_uploaded']
  state_changed = t_dict['rtorrent']['state_changed']
  t_state = t_dict['rtorrent']['state'] # 0|1
  t_complete = t_dict['rtorrent']['complete'] # 0|1
  t_ignores_orders = t_dict['rtorrent']['ignore_commands']

  share_ratio = 0
  complete_percent = 0

  if total_uploaded > 0 and total_downloaded > 0
    share_ratio = total_uploaded.to_f / total_downloaded.to_f
  end
  
  if not t_complete == 1 and total_downloaded > 0
    complete_percent = (total_downloaded.to_f / t_size.to_f) * 100
  end

  if t_complete == 1
    complete_percent = 100
    total_downloaded = t_size
  end

  # Add link for download only if torrent complete
  if t_complete == 1 
    file_output << "<a href=\"#{@torrents_dir}#{t_name}\">#{t_name}</a> - #{started_stoped(t_state, t_complete)} #{ignores(t_ignores_orders)}:"
  else
    file_output << "#{t_name} - #{started_stoped(t_state, t_complete)} #{ignores(t_ignores_orders)}:"
  end

  file_output << "size: #{sz(t_size)}"
  file_output << "downloaded: #{sz(total_downloaded)}"
  file_output << "uploaded: #{sz(total_uploaded)}"
  file_output << "complete: #{"%0.2f" % complete_percent}%"
  file_output << "ratio: #{"%0.2f" % share_ratio}"


  if t_complete == 1
    ret_status = "FINISHED"
  else
    ret_status = ""
  end

  return ret_status, file_output
end

# *** main program ***

session_dir = "/home/anton/rtorrent" # path rtorrent session dir (.rtorrent.rc#session)
session_list = Dir.entries(session_dir).select {|e| File.extname(e) == ".torrent"}
session_list.map!{|e| session_dir + "/" + e}

page_head = []
started_list = []
finished_list = []

tc = Time.now - tb
page_head << "Generating in #{"%0.5f" % tc} seconds" + "\n"
page_head << "Last Update: #{Time.now.strftime("%H:%M:%S, %Y-%m-%d")}" + "\n"

session_list.each {|torrent|
  tor_status, tor_text = get_status(torrent)
  if tor_status == "FINISHED"
    finished_list << tor_text
  else
    started_list << tor_text
  end
}

torstarted = ""
torfinished = ""

finished_list.each {|line|
  line.each{|val|
    torfinished << val+"\n"
  }
  torfinished << "\n"
}

started_list.each {|line|
  line.each{|val|
    torstarted << val+"\n"
  }
  torstarted << "\n"
}

print eval( '"' + status_page + '"' ) #generate web page from template

