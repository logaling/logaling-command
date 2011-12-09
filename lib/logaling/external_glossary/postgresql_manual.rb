require 'open-uri'
require 'nokogiri'

module Logaling
  class PostgresqlManual < ExternalGlossary
    def import
      buffer = ""
      CSV.generate(buffer) do |csv|
        doc = ::Nokogiri::HTML(open("http://osb.sraoss.co.jp/PostgreSQL/Manual/word.html", "r:iso-2022-jp").read.encode("utf-8"))
        doc.css('table table tr')[2..-1].each do |tr|
          if tr.children[2]
            csv << [tr.children[2].text, tr.children[4].text]
          end
        end
      end
      File.open("postgresql_manual.en.ja.csv", "w") {|f| f.write(buffer) }
    end
  end
end
