require 'open-uri'
require 'nokogiri'

module Logaling
  class PostgresqlManual < ExternalGlossary
    description     'PostgreSQL7.1 Manual(http://osb.sraoss.co.jp/PostgreSQL/Manual/)'
    source_language 'en'
    target_language 'ja'

    def convert
      buffer = ""
      CSV.generate(buffer) do |csv|
        doc = ::Nokogiri::HTML(open("http://osb.sraoss.co.jp/PostgreSQL/Manual/word.html", "r:iso-2022-jp").read.encode("utf-8"))
        doc.css('table table tr')[2..-1].each do |tr|
          if tr.children[2]
            csv << [tr.children[2].text, tr.children[4].text]
          end
        end
      end
    end
  end
end
