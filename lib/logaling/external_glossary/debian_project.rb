require 'open-uri'
require 'nokogiri'

module Logaling
  class DebianProject < ExternalGlossary
    def import
      buffer = ""
      CSV.generate(buffer) do |csv|
        doc = ::Nokogiri::HTML(open("http://www.debian.or.jp/community/translate/trans_table.html", "r"))
        doc.css('dl').each do |dl|
          dl.children.each_slice(3) do |dt, dd, _|
            csv << [dt.text, dd.text.gsub(/(^\/|\/$)/,'')]
          end
        end
      end
      File.open("debian_project.en.ja.csv", "w") {|f| f.write(buffer) }
    end
  end
end
