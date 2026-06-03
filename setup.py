import yfinance as yf
import pandas as pd

tickers = [
    'ABBV', 'NVS', 'PFE', 'LLY', 'MRK', 'AZN', 'GSK', 'BMY',
    'JNJ', 'SNY', 'BAYRY', 'NVO', 'TAK', 'RHHBY', 'AMGN', 'GILD',
    'BIIB', 'REGN', 'VRTX', 'BMRN', 'INCY', 'SRPT', 'RARE', 'ALNY',
    'EXEL', 'IONS', 'NBIX', 'ARGX', 'UTHR', 'JAZZ', 'SPY'
]

print("Downloading Prices...")
prices = yf.download(tickers, start="2009-01-01",
                     end="2025-12-31", auto_adjust=True)['Close']
prices = prices.reset_index()
prices_long = prices.melt(
    id_vars='Date', var_name='ticker', value_name='close_price')
prices_long = prices_long.dropna()
prices_long.to_csv("data/stock_prices.csv", index=False)
print(f"Saved {len(prices_long)} records in data/stock_prices.csv")
