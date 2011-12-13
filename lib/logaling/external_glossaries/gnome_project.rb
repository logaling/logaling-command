require 'open-uri'
require 'nokogiri'

module Logaling
  class GnomeProject < ExternalGlossary
    description     'GNOME Translation Project Ja (http://live.gnome.org/TranslationProjectJa)'
    source_language 'en'
    target_language 'ja'

    def convert
      buffer = ""
      CSV.generate(buffer) do |csv|
        doc = ::Nokogiri::HTML(open("http://www.gnome.gr.jp/l10n/trans-terms.html", "r"))
        doc.css('table tr')[1..-1].each do |tr|
          csv << [tr.children[0].text, tr.children[1].text]
        end
      end
    end
  end
end
