STRIKE_THRESHOLD = 0.25 # fraction of stock price: decides how many strikes to look at 
RETURN_THRESHOLD = 4 #in annualized %
RJUST_SPACING = 8

$stock_price = 0
$ticker = ''
$expiry = ''
$option_data_array = Hash.new{|hsh,key| hsh[key] = [] }
$days_to_expiry = 0
$puts_or_calls = "put"
$stocks = YAML.load_file('public/sp500.yml')

class YahooController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def initData
    $stock_price = 0
    $ticker = ''
    $expiry = ''
    $option_data_array = Hash.new{|hsh,key| hsh[key] = [] }
    $days_to_expiry = 0
    $puts_or_calls = "put"
  end
  
  def fetchOptionData  

#Misc links
    #https://query1.finance.yahoo.com/v10/finance/quoteSummary/AAPL?formatted=true&crumb=B2JsfXH.lpf&lang=en-US&region=US&modules=incomeStatementHistory%2CcashflowStatementHistory%2CbalanceSheetHistory%2CincomeStatementHistoryQuarterly%2CcashflowStatementHistoryQuarterly%2CbalanceSheetHistoryQuarterly%2Cearnings&corsDomain=finance.yahoo.com%27
    #https://query2.finance.yahoo.com/v10/finance/quoteSummary/AAPL?formatted=true&crumb=8ldhetOu7RJ&lang=en-US&region=US&modules=defaultKeyStatistics%2CfinancialData%2CcalendarEvents&corsDomain=finance.yahoo.com'

    initData()
    @ticker = params[:ticker].strip.upcase
    @daysToExpiry = params[:daysToExpiry].strip.to_i
    $puts_or_calls = params[:post]["category"]

    url = "https://query2.finance.yahoo.com/v7/finance/options/#{@ticker}"
    uri = URI(url)
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)

    #Step 1: Get stock price
    stockPrice = data["optionChain"]["result"][0]["quote"]["regularMarketPrice"].to_f

    # Step 2: Get expiry dates and closest expiry 
    expiryDates = data["optionChain"]["result"][0]["expirationDates"]

    closestExpiry = 0
    closestTimeToExpiry = 10000 #high value
    expiryDates.each do |date|
      #expiry = DateTime.strptime(date.to_s,"%s") # convert from unix time to date
      #expiry_date = Date.parse(expiry.to_s) # change format
      timeToExpiry = (date - Time.now.to_i)/86400
  
      if((timeToExpiry - @daysToExpiry).abs < closestTimeToExpiry)
        closestExpiry = date
        closestTimeToExpiry = (timeToExpiry - @daysToExpiry).abs
      end
    end    
  
    @daysToExpiry = (closestExpiry - Time.now.to_i)/86400
  
    $ticker = @ticker
    $stock_price = stockPrice
    $expiry = Date.parse(DateTime.strptime(closestExpiry.to_s,"%s").to_s)
    $days_to_expiry = @daysToExpiry  

    # Step 3: Get option data for closest expiry    
    url = "https://query2.finance.yahoo.com/v7/finance/options/#{@ticker}?date=#{closestExpiry}"
    uri = URI(url)
    response = Net::HTTP.get(uri)

    data = JSON.parse(response)
    
    if($puts_or_calls == "put")
      putData = data["optionChain"]["result"][0]["options"][0]["puts"]
     
      putData.each_with_index do |contract, i|
       contract_name = contract["contractSymbol"]
       strike = contract["strike"].to_f.round(2)
       price = ((contract["bid"].to_f + contract["ask"].to_f)/2.round(2)).round(2)
       percent_away = (($stock_price/strike-1)*100).round(0)
       iv = ('%.2f' % (contract["impliedVolatility"]*100).round(2))
       volume = contract["volume"]
       percent_return = ((price/strike)*365*100/@daysToExpiry).round(2) 
   
      
       if( (strike > (1-STRIKE_THRESHOLD)*$stock_price) && (strike < $stock_price) && (percent_return > RETURN_THRESHOLD))
        price = ('%.2f' % price) 
        percent_return = ('%.2f' % percent_return)
        $option_data_array[i].push [contract_name, strike, percent_away, price, volume, iv, percent_return]
       end
     end
   elsif
     callData = data["optionChain"]["result"][0]["options"][0]["calls"]
     
     callData.each_with_index do |contract, i|
      contract_name = contract["contractSymbol"]
      strike = contract["strike"].to_f.round(2)
      price = ((contract["bid"].to_f + contract["ask"].to_f)/2.round(2)).round(2)
      percent_away = ((1-$stock_price/strike)*100).round(0)
      iv = ('%.2f' % (contract["impliedVolatility"]*100).round(2))
      volume = contract["volume"]
      percent_return = ((price/strike)*365*100/@daysToExpiry).round(2) 
   
      
      if( (strike < (1+STRIKE_THRESHOLD)*$stock_price) && (strike > $stock_price) && (percent_return > RETURN_THRESHOLD))
       price = ('%.2f' % price) 
       percent_return = ('%.2f' % percent_return)
       $option_data_array[i].push [contract_name, strike, percent_away, price, volume, iv, percent_return]
      end   
    end
   end
          
    render 'index' 
  end

 def clearData
   initData()
   render 'index'
 end  
end



