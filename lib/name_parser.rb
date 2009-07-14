module NameParser

  extend self

  Titles = %w(Mr Dr Mrs Miss Professor Prof Doctor Ms)
  Qualifications = %w(B.Sc. B.A. Ph.D. D.Phil. C.B.E. O.B.E. J.P.)
  
  def parse(fn)
    poss_quals = Qualifications + Qualifications.map{|e| e.gsub('.','')}
    titles, qualifications, result_hash = [], [], {}
    fn = fn.sub(/Councillor|Councilllor|Cllr/, '')
    qualifications = poss_quals.collect{ |q| fn.slice!(q)}.compact
    names = fn.gsub(/([.,])/, ' ').gsub(/\([\w ]+\)/, '').gsub(/[A-Z]{3,}/, '').split(" ")
    names.delete_if{ |n| Titles.include?(n) ? titles << n : false}

    result_hash[:first_name] = names[0..-2].join(" ")
    result_hash[:last_name] = names.last
    result_hash[:name_title] = titles.join(" ") unless titles.empty?
    result_hash[:qualifications] = qualifications.join(" ") unless qualifications.empty?
    result_hash
  end
end