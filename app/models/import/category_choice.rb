class Import::CategoryChoice < Data.define(:word, :name, :money_in)
  def self.from(params)
    new(word: params[:word], name: params[:name].to_s.squish, money_in: params[:money_in]&.to_s&.squish)
  end

  def keeps_money_in?
    money_in.nil?
  end
end
