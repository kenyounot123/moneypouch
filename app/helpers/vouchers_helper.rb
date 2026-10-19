module VouchersHelper
  def voucher_marks(voucher)
    voucher.tokens.map do |token|
      kind = token.kind == :amount && voucher.money_in? ? :money_in : token.kind
      [ kind, utf16_length(voucher.shorthand[0, token.start]), utf16_length(voucher.shorthand[0, token.finish]) ]
    end
  end

  private
    def utf16_length(text)
      text.encode("UTF-16LE").bytesize / 2
    end
end
