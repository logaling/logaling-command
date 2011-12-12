require 'open-uri'
require 'nokogiri'

module Logaling
  class DebianProject < ExternalGlossary
    description     'Debian JP Project (http://www.debian.or.jp/community/translate/)'
    source_language 'en'
    target_language 'ja'

    def convert
      buffer = ""
      CSV.generate(buffer) do |csv|
        doc = ::Nokogiri::HTML(open("http://www.debian.or.jp/community/translate/trans_table.html", "r"))
        doc.css('dl').each do |dl|
          dl.children.each_slice(3) do |dt, dd, _|
            csv << [dt.text, dd.text.gsub(/(^\/|\/$)/,'')]
          end
        end
      end
    end
  end
end
