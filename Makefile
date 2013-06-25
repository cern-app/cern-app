.PHONY:  encode encodeTwitter

all: Src/Utilities/Readability-tokens.h Src/Utilities/Twitter-tokens.h

Src/Utilities/Readability-tokens.h: Src/Utilities/Readability-tokens.h.enc
	openssl enc -base64 -aes-256-cbc -d -in $< > $@	

Src/Utilities/Twitter-tokens.h: Src/Utilities/Twitter-tokens.h.enc
	openssl enc -base64 -aes-256-cbc -d -in $< > $@

encode:
	openssl enc -base64 -aes-256-cbc -in Src/Utilities/Readability-tokens.h -out Src/Utilities/Readability-tokens.h.enc

encodeTwitter:
	openssl enc -base64 -aes-256-cbc -in Src/Utilities/Twitter-tokens.h -out Src/Utilities/Twitter-tokens.h.enc
