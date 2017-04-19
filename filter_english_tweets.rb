# Ruby 2.1.5
# This script extracts English Tweets out of the Twitter Corpus in JSON format
# It will account for .dat files located in all subdirectories of the current working dir

require 'json'         # parse and create JSON strings
require 'whatlanguage' # language detection, external gem

# log results in file
LOGFILE = File.join(Dir.pwd, "filter_english_tweets.log")

# words beginning with any of the following sequences 
PREFIX_FILTER = [
  "@",
  "#",
  "http"
]

# max 30% of a tweet may consist of non-ASCII characters
NON_ASCII_RATIO_THRESHOLD = 0.3





# filter any words that begin with one of the prefix filters
def filter_keywords(tweet)
  return tweet.split(" ")                                                                # create array of words
    .reject { |word| PREFIX_FILTER.any? { |filter| word.downcase.start_with?(filter) } } # remove words matching a PREFIX_FILTER
    .join(" ")                                                                           # concatenate array of words with spaces
end

# get ratio of non-ASCII characters, leave spaces
def non_ascii_characters_ratio(tweet)
  return tweet.gsub(" ", "").chars.count { |char| char.ord > 127 }.to_f / tweet.gsub(" ", "").length
end

# tweet is English by user language setting?
def tweet_language_english?(tweet)
  return tweet["user"] && tweet["user"]["lang"].eql?("en")
end

# tweet contains 70% ASCII chars or more?
def tweet_enough_ascii?(tweet)
  return non_ascii_characters_ratio(tweet["text"]) <= NON_ASCII_RATIO_THRESHOLD
end



# initialize language detection with all filters (likely fails most of the time since text is too short)
wl = WhatLanguage.new(:all)
log = []

# used to collect statistics over all of the processed files
tweets                       = 0
tweets_user_english          = 0
tweets_enough_ascii          = 0
tweets_passed                = 0
tweets_passed_with_non_ascii = 0

# get all elements in working directory
subdirs = Dir[File.join(Dir.pwd, "*")].select { |element| Dir.exist?(element) }
log.push("Processing #{subdirs.count} directories")
subdirs.each_with_index do |dir, idx1|
  puts("Processing directory #{(idx1 + 1).to_s.rjust(subdirs.count.to_s.length)} / #{subdirs.length}: #{dir}")
  log.push("  Processing #{dir}")
  # process each .dat file in subdirectory, assume as JSON-array of tweets
  dat_files = Dir[File.join(dir, "*.dat")]
  log.push("    Processing #{dat_files.count} .dat-files")
  dat_files.each_with_index do |dat_file, idx2|
    puts("  Processing .dat-file #{(idx2 + 1).to_s.rjust(dat_files.count.to_s.length)} / #{dat_files.length}: #{dat_file}")
    log.push("      Processing #{dat_file}")
    json_content = JSON.parse(File.read(dat_file))
    
    # filter tweets by ASCII threshold and user language setting
    english_tweets_text = json_content.each_with_object([]) do |tweet, array|
      array.push(tweet["text"]) if tweet_language_english?(tweet) && tweet_enough_ascii?(tweet)
    end

    # determine statistics for the current file
    current_tweets                       = json_content.count
    current_tweets_user_english          = json_content.count { |tweet| tweet_language_english?(tweet) }
    current_tweets_enough_ascii          = json_content.count { |tweet| tweet_enough_ascii?(tweet) }
    current_tweets_passed                = english_tweets_text.count
    current_tweets_passed_with_non_ascii = english_tweets_text.count { |text| non_ascii_characters_ratio(text) > 0 }

    # add to global statistics    
    tweets                       += current_tweets
    tweets_user_english          += current_tweets_user_english
    tweets_enough_ascii          += current_tweets_enough_ascii
    tweets_passed                += current_tweets_passed
    tweets_passed_with_non_ascii += current_tweets_passed_with_non_ascii
    
    # add to log
    log.push("        #{current_tweets} Tweets")
    log.push("        #{current_tweets_user_english} English according to User")
    log.push("        #{current_tweets_enough_ascii} with at least #{((1 - NON_ASCII_RATIO_THRESHOLD) * 100).to_i}% ASCII")
    log.push("        #{current_tweets_passed} fulfill both criteria (will be written), of which")
    log.push("        #{current_tweets_passed_with_non_ascii} contain non-ASCII chars at all")
    # write JSON array of plain text
    #  all text, including prefix-filterable content
    File.open("#{dat_file}_en", "w+") { |file| file.write(JSON.generate(english_tweets_text)) }
    #  only the prefix-filtered content
    File.open("#{dat_file}_en_filtered", "w+") { |file| file.write(JSON.generate(english_tweets_text.map { |tweet| filter_keywords(tweet) })) }
  end
end
log.push("Totals:")
log.push("#{tweets} Tweets")
log.push("#{tweets_user_english} English according to User")
log.push("#{tweets_enough_ascii} with at least #{((1 - NON_ASCII_RATIO_THRESHOLD) * 100).to_i}% ASCII")
log.push("#{tweets_passed} fulfill both criteria (will be written), of which")
log.push("#{tweets_passed_with_non_ascii} contain non-ASCII chars at all")
File.open(LOGFILE, "w+") { |file| file.write(log.join("\n")) }