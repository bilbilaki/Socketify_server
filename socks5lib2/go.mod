module socks5lib2

go 1.25.4

replace bridge => ./bridge

require (
	bridge v0.0.0-00010101000000-000000000000
	github.com/txthinking/socks5 v0.0.0-20251011041537-5c31f201a10e
)

require (
	github.com/patrickmn/go-cache v2.1.0+incompatible // indirect
	github.com/txthinking/runnergroup v0.0.0-20210608031112-152c7c4432bf // indirect
)
