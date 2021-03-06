#' ---
#' title: "Twitter Analysis"
#' author: "Tony"
#' output:
#'   html_document:
#'     toc: true
#'     toc_depth: 6
#' params:
#'   person1: "Tony"
#'   person2: "Andrew"
#' ---
#'
#+ global_options, include = FALSE
# rmarkdown::render("tweets.R", output_file = paste0("tweets_report_", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".html"))
# knitr::spin("tweets.R", knit = FALSE)
knitr::opts_chunk$set(
  echo = FALSE,
  results = "hide",
  warning = FALSE,
  message = FALSE
)

rm(list = ls())
# setwd("O:/_other/code/tony")
knitr::opts_knit$set(root.dir = "O:/_other/code/tony")
params <-
  list(
    person1 = "BarstoolBigCat",
    person2 = "PFTCommenter",
    download = FALSE,
    tweets_retrieve_max = 3200,
    tweets_resize_min = 3000
  )

#'
#'
#'
#+ setup
# Explicitly listing thse since they will be used often.
# person1 <- "tony"
# person2 <- "andrew"
person1 <- params$person1
person2 <- params$person2

persons <- unique(sort(c(person1, person2)))
if (persons[1] != person1) {
  person0 <- person1
  person1 <- person2
  person2 <- person0
}

#'
#'
#'
#+ download

if(params$download == TRUE) {
  require("rtweets")
  tweets_person1 <- get_timeline(person1, n = params$tweets_retrieve_max)
  tweets_person2 <- get_timeline(person2, n = params$tweets_retrieve_max)
} else {
  # This csv's with the suffix "-manual" are from the manual download of personal archives.
  # The rtweets package was used to create these files.
  require("dplyr")
  require("stringr")
  tweets_person1 <-
    paste0("data/tweets_", person1, ".csv") %>%
    read.csv(stringsAsFactors = FALSE) %>%
    tbl_df()
  tweets_person2 <-
    paste0("data/tweets_", person2, ".csv") %>%
    read.csv(stringsAsFactors = FALSE) %>%
    tbl_df()
}

#'
#' # Introduction
#'
#' This report compares the volume, behavior, and content of the tweets made by
#' `r person1` and `r person2`.
#'
#+ import

library("dplyr")
library("stringr")
colnames_id <-
  tweets_person1 %>%
  names() %>%
  str_subset("id")

library("lubridate")
# Need to convert id columns to numeric explicitly in case they
# are imported as character types (which is possible if all values are NAS).
tweets <-
  bind_rows(
    tweets_person1 %>%
      mutate_at(vars(colnames_id), funs(as.numeric)) %>%
      mutate(person = person1),
    tweets_person2 %>%
      mutate_at(vars(colnames_id), funs(as.numeric)) %>%
      mutate(person = person2)
  ) %>%
  mutate(timestamp = ymd_hms(created_at)) %>%
  mutate(timestamp = with_tz(timestamp, "America/Chicago")) %>%
  mutate(time = as.numeric(timestamp - trunc(timestamp, "days"))) %>%
  mutate(time = as.POSIXct(time, origin = "1970-01-01"))
#'
#'
#'
#+ include = FALSE
# Check for bad values.
tweets %>%
  mutate(
    hour = hour(timestamp),
    min = minute(timestamp),
    sec = second(timestamp)
  ) %>%
  filter(hour == 0 & min == 0 & sec == 0) %>%
  nrow()

tweets %>% filter(is.na(time)) %>% nrow()
#'
#'
#'

# A cstom function is used because this set of operations is done multiple times.
get_totals <- function(d) {
  d %>%
    group_by(person) %>%
    summarise(total = n()) %>%
    ungroup() %>%
    select(person, total)
}

tweet_totals <- tweets %>% get_totals()
tweet_totals

calculate_elapsed_time <- function(start_date, end_date, type) {
  if(type == "years" | type == "months") {
    sd <- as.POSIXlt(start_date)
    ed <- as.POSIXlt(end_date)
    if(type == "years") {
      (ed$year - sd$year) - 1
    } else if (type == "months") {
      12 * (ed$year - sd$year) + (ed$mon - sd$mon) - 1
    }
  } else if (type == "days" | type == "hours") {
    (difftime(end_date, start_date, units = type) - 1) %>%
      round(0) %>%
      as.numeric()
  }
}

tweet_times <-
  tweets %>%
  group_by(person) %>%
  arrange(timestamp) %>%
  mutate(
    start_date = first(timestamp),
    end_date = last(timestamp)
  ) %>%
  slice(1) %>%
  ungroup() %>%
  select(person, start_date, end_date) %>%
  mutate(
    years_elapsed = calculate_elapsed_time(start_date, end_date, "years"),
    months_elapsed = calculate_elapsed_time(start_date, end_date, "months"),
    days_elapsed = calculate_elapsed_time(start_date, end_date, "days"),
    hours_elapsed = calculate_elapsed_time(start_date, end_date, "hours")
  )
tweet_times

tweet_firstend <- min(tweet_times$end_date)
tweet_firstend
tweets <- tweets %>% filter(timestamp < tweet_firstend)

tweet_totals_trim1 <- tweets %>% get_totals()
tweet_totals_trim1

tweet_laststart <- max(tweet_times$start_date)
tweet_laststart

tweets_resize_min <- params$tweets_resize_min
if(min(tweet_totals$total) < params$tweets_resize_min) {
  # Only doing this to have a dummy data frame.
  tweet_totals_trim2 <- tweet_totals_trim1
} else {

  tweets <-
    tweets %>%
    filter(timestamp >= tweet_laststart)

  tweet_totals_trim2 <- tweets %>% get_totals()
}


#'
#' `r tweet_totals$total[1]` tweets were orignally collected for `r person1`.
#' `r tweet_totals$total[2]` tweets were originally collected for `r person2`.
#'
#' The oldest tweet collected from `r person1` is
#' from `r tweet_times$start_date[1]` and the oldest tweet from
#' `r person2` is from `r tweet_times$start_date[2]`. The most recent tweets
#' are from `r tweet_times$end_date[1]` and `r tweet_times$end_date[2]`
#'
#' The two sets of tweets were trimmed to `r tweet_totals_trim1$total[1]` and
#' `r tweet_totals_trim1$total[2]` tweets respectively in order to
#' align the dates of the last collected tweets.
#'
#'
#+ eval = (min(tweet_totals$total) >= tweets_resize_min), results = "asis"
cat(
  sprintf(
  "Because the number of tweets for at least one of the people is less than
  the threshhold %d, the data sets were resized such that they cover
  the same periods of time.
  The number of tweets from %s and %s were reduced to %i and %i.",
  params$tweets_resize_min, person1, person2,
  tweet_totals_trim2$total[1], tweet_totals_trim2$total[2]
  )
)

#'
#' # Tweet Volume
#'
#' How often do `r person1` and `r person2` tweet?
#' Does the volume of tweets look different for
#' temporal periods?
#'
#+
library("ggplot2")
theme_set(theme_minimal())

# geom_bar() doesn't work if timestamp is grouped in some way.
# tweets %>%
#   ggplot(aes(x = timestamp)) +
#   geom_histogram(aes(y = ..count.., fill = person)) +
#   theme(legend.position = "bottom") +
#   theme(strip.text = element_blank()) +
#   guides(fill = guide_legend(title = NULL)) +
#   labs(
#     x = NULL,
#     y = NULL,
#     title = "Count of Tweets Over Time",
#     subtitle = "Unbound Time Frame"
#   ) +
#   facet_wrap(~ person, ncol = 1)

tweets %>%
  ggplot(aes(x = timestamp)) +
  geom_histogram(aes(y = ..count.., fill = person)) +
  theme(legend.position = "bottom") +
  theme(strip.text = element_blank()) +
  guides(fill = guide_legend(title = NULL)) +
  labs(
    x = NULL,
    y = NULL,
    title = "Count of Tweets Over Time",
    subtitle = str_c("From ", tweet_laststart, " to ", tweet_firstend)
  ) +
  facet_wrap(~ person, ncol = 1)

# If using geom_histogram(),
# specify ".5" in the breaks so that the columns appear centered
if(min(tweet_times$years_elapsed) > 2) {
  tweets %>%
    ggplot(aes(x = year(timestamp))) +
    # geom_histogram(aes(y = ..count.., fill = person), breaks = seq(2014.5, 2017.5, by = 1)) +
    geom_bar(aes(y = ..count.., fill = person)) +
    theme(legend.position = "bottom") +
    theme(strip.text = element_blank()) +
    guides(fill = guide_legend(title = NULL)) +
    labs(
      x = NULL,
      y = NULL,
      title = "Count of Tweets Over Time",
      subtitle = "Grouped By Year"
    ) +
    facet_wrap(~ person, ncol = 1, scales = "free")
}

if(min(tweet_times$months_elapsed) >= 3) {
  tweets %>%
    ggplot(aes(x = month(timestamp, label = TRUE))) +
    geom_bar(aes(y = ..count.., fill = person)) +
    theme(legend.position = "bottom") +
    theme(strip.text = element_blank()) +
    guides(fill = guide_legend(title = NULL)) +
    labs(
      x = NULL,
      y = NULL,
      title = "Count of Tweets Over Time",
      subtitle = "Grouped By Month"
    ) +
    facet_wrap(~ person, ncol = 1, scales = "free")
}

if(min(tweet_times$days_elapsed) >= 7) {
    tweets %>%
    ggplot(aes(x = wday(timestamp, label = TRUE))) +
    geom_bar(aes(y = ..count.., fill = person)) +
    theme(legend.position = "bottom") +
    theme(strip.text = element_blank()) +
    guides(fill = guide_legend(title = NULL)) +
    labs(
      x = NULL,
      y = NULL,
      title = "Count of Tweets Over Time",
      subtitle = "Grouped By Day of Week"
    ) +
    facet_wrap(~ person, ncol = 1, scales = "free")
}

library("scales")
if(min(tweet_times$hours_elapsed) >= 24) {
  tweets %>%
    ggplot(aes(x = time)) +
    geom_histogram(aes(y = ..count.., fill = person)) +
    scale_x_datetime(
      breaks = date_breaks("4 hours"),
      labels = date_format("%H:00")
    ) +
    theme(legend.position = "bottom") +
    theme(strip.text = element_blank()) +
    guides(fill = guide_legend(title = NULL)) +
    labs(
      x = NULL,
      y = NULL,
      title = "Count of Tweets Over Time",
      subtitle = "Grouped By Hour of Day"
    ) +
    facet_wrap(~ person, ncol = 1, scales = "free")
}

#'
#' Is the distribution of our volume of tweets given a certain temporal period
#' statistically significant? Here, I use the Chi-Squared Test. If the p-value
#' is calculated to be less thatn some threshold value (e.g. 0.05), then I can
#' deduce that the the null hypothes (that the distribution is uniform) is
#' invalid. In fact, it appears that our tweet volume does differ
#' depending on the month and day of the week.
#'
# Statistical significance of count given month.
# Can't really use group_by() here. Must use separate statements
tweets %>%
  filter(person == person1) %>%
  pull(timestamp) %>%
  month(label = TRUE) %>%
  table() %>%
  chisq.test()

tweets %>%
  filter(person == person2) %>%
  pull(timestamp) %>%
  month(label = TRUE) %>%
  table() %>%
  chisq.test()

# Statistical significance of count given day of week.
tweets %>%
  filter(person == person1) %>%
  pull(timestamp) %>%
  wday(label = TRUE) %>%
  table() %>%
  chisq.test()

tweets %>%
  filter(person == person2) %>%
  pull(timestamp) %>%
  wday(label = TRUE) %>%
  table() %>%
  chisq.test()

# Statistical significance of count given day of weeks categorized as either
# weekday and weekend.
tweets_person1_table <-
  tweets %>%
  filter(person == person1) %>%
  pull(timestamp) %>%
  wday(label = TRUE) %>%
  table()

tweets_person2_table <-
  tweets %>%
  filter(person == person2) %>%
  pull(timestamp) %>%
  wday(label = TRUE) %>%
  table()

# Value greater than 1 indicates more tweets during weekdays.
weekday_avg_person1 <- mean(tweets_person1_table[c(2:5)]) / mean(tweets_person1_table[c(1, 6, 7)])
weekday_avg_person1
weekday_avg_person2 <- mean(tweets_person2_table[c(2:5)]) / mean(tweets_person2_table[c(1, 6, 7)])
weekday_avg_person2

tweets %>%
  filter(person == person1) %>%
  pull(timestamp) %>%
  wday(label = TRUE) %>%
  table() %>%
  chisq.test(p = c(1, rep(weekday_avg_person1, 4), 1, 1) / (3 * 1 + 4 * weekday_avg_person1))

tweets %>%
  filter(person == person2) %>%
  pull(timestamp) %>%
  wday(label = TRUE) %>%
  table() %>%
  chisq.test(p = c(1, rep(weekday_avg_person2, 4), 1, 1) / (3 * 1 + 4 * weekday_avg_person2))

#'
#' # Tweet Behavior
#'
#' What proportion of tweets include more than just plain text
#' (e.g. hashtags, links, etc.)?
#' What proportion are not undirected, self-authored tweets
#' (i.e. RTs or replies)?
#'
# Showing 2 ways to detect hashtags and links from the dataframe.
# The twwitteR package does not return explicit info regarding hashtags and urls
# like the rtweet package, so the the non-suffixed versions were necessary
# before.
# Noticeably, the link2 value is somewhat different from the non-suffixed version.
# library("stringr")
tweets <-
  tweets %>%
  mutate(
    has_hashtag = ifelse(str_detect(text, "#") == TRUE, 1, 0),
    has_hashtag2 = ifelse(!is.na(hashtags), 1, 0),
    has_link = ifelse(str_detect(text, "t.co") == TRUE, 1, 0),
    has_link2 = ifelse(!(is.na(media_url) & is.na(urls_display)), 1, 0),
    is_rt = ifelse(is_retweet == TRUE, 1, 0),
    is_reply = ifelse(!is.na(in_reply_to_status_user_id), 1, 0)
  ) %>%
  mutate(
    type = ifelse(is_rt == TRUE, "RT", ifelse(is_reply == TRUE, "reply", "original"))
  )

calculate_pct <- function(x, value, digits_round = 4) {
  round(sum(x == value) / sum(!is.na(x)), digits_round)
}

library("tidyr")
tweets_type_summary <-
  tweets %>%
  group_by(person) %>%
  summarise(
    hashtag_yes = calculate_pct(has_hashtag, 1),
    hashtag2_yes = calculate_pct(has_hashtag2, 1),
    hashtag_no = calculate_pct(has_hashtag, 0),
    hashtag2_no = calculate_pct(has_hashtag2, 0),
    link_yes = calculate_pct(has_link, 1),
    link2_yes = calculate_pct(has_link2, 1),
    link_no = calculate_pct(has_link, 0),
    link2_no = calculate_pct(has_link2, 0),
    rt_yes = calculate_pct(is_rt, 1),
    rt_no = calculate_pct(is_rt, 0),
    reply_yes = calculate_pct(is_reply, 1),
    reply_no = calculate_pct(is_reply, 0)
  ) %>%
  ungroup() %>%
  gather(key, value, -person) %>%
  separate(key, c("type", "response"), sep = "_")
tweets_type_summary


#'
#'
#+ include = FALSE


# Could specify positon for geom_col() in a similar as is done for
# geom_label() in order to create spacing between the bars.
# guides() method is preferred compared to theme(legend.title = element_blank())
# to allow for specificity.
tweets_type_summary %>%
  filter(type == "hashtag") %>%
  ggplot(aes(x = response)) +
  geom_col(aes(y = value, fill = person), position = "dodge") +
  geom_label(
    aes(
      y = value,
      group = person,
      label = paste(100 * value, "%")
    ),
    position = position_dodge(width = 1)
  ) +
  scale_y_continuous(labels = percent_format()) +
  theme(legend.position = "bottom") +
  guides(fill = guide_legend(title = NULL)) +
  labs(x = NULL, y = NULL, title = "% of Tweets with Hashtags")

tweets_type_summary %>%
  filter(type == "link") %>%
  ggplot(aes(x = response)) +
  geom_col(aes(y = value, fill = person), position = "dodge") +
  geom_label(
    aes(
      y = value,
      group = person,
      label = paste(100 * value, "%")
    ),
    position = position_dodge(width = 1)
  ) +
  scale_y_continuous(labels = percent_format()) +
  theme(legend.position = "bottom") +
  guides(fill = guide_legend(title = NULL)) +
  labs(x = NULL, y = NULL, title = "% of Tweets with Links")

tweets_type_summary %>%
  filter(type == "rt") %>%
  ggplot(aes(x = response)) +
  geom_col(aes(y = value, fill = person), position = "dodge") +
  geom_label(
    aes(
      y = value,
      group = person,
      label = paste(100 * value, "%")
    ),
    position = position_dodge(width = 1)
  ) +
  scale_y_continuous(labels = percent_format()) +
  theme(legend.position = "bottom") +
  guides(fill = guide_legend(title = NULL)) +
  labs(x = NULL, y = NULL, title = "% of Tweets that are RTs")

tweets_type_summary %>%
  filter(type == "reply") %>%
  ggplot(aes(x = response)) +
  geom_col(aes(y = value, fill = person), position = "dodge") +
  geom_label(
    aes(
      y = value,
      group = person,
      label = paste(100 * value, "%")
    ),
    position = position_dodge(width = 1)
  ) +
  scale_y_continuous(labels = percent_format()) +
  theme(legend.position = "bottom") +
  guides(fill = guide_legend(title = NULL)) +
  labs(x = NULL, y = NULL, title = "% of Tweets that are Replies")

tweets %>%
  ggplot(aes(x = timestamp, fill = type)) +
  geom_histogram(position = "fill") +
  scale_y_continuous(labels = percent_format()) +
  theme(legend.position = "bottom") +
  guides(fill = guide_legend(title = NULL)) +
  labs(x = NULL, y = NULL, title = "Distribution of Tweets by Type Over Time") +
  facet_wrap(~ person, ncol = 1, scales = "free")

#'
#' # Tweet Content
#'
#' How long are the tweets?
#'
#+ include = FALSE
# Note that there are some tweets above 140 characters.
tweets %>%
  mutate(char_count = str_length(text)) %>%
  ggplot(aes(x = char_count)) +
  geom_histogram(aes(fill = ..count..), bin_width = 10)

tweets %>%
  mutate(char_count = str_length(text)) %>%
  filter(char_count > 150) %>%
  pull(text)

#'
#'
#'
# Attempt to address tweets with greater than 140 characters
tweets <-
  tweets %>%
  mutate(char_count = str_length(text))

tweets %>%
  filter(char_count > 150) %>%
  summarise(
    char_count_count = n(),
    char_count_avg = mean(char_count),
    char_count_max = max(char_count)
  )

tweets %>%
  filter(char_count <= 150) %>%
  ggplot(aes(x = char_count)) +
  geom_histogram(aes(y = ..count.., fill = person), binwidth = 10) +
  theme(legend.position = "none") +
  labs(x = NULL, y = NULL, title = "Distribution of # of Characters in Tweets") +
  facet_wrap(~ person, ncol = 1, scales = "free")

#'
#' ## Word Frequency and Usage
#'
#' Which words are used most frequently?
#'
library("tidytext")
unnest_regex <- "([^A-Za-z_\\d#@']|'(?![A-Za-z_\\d#@]))"
replace_regex <- "https://t.co/[A-Za-z\\d]+|http://[A-Za-z\\d]+|&amp;|&lt;|&gt;|RT|https"

tweets_tidy <-
  tweets %>%
  # filter(!str_detect(text, "^(RT|@)")) %>%
  mutate(text = str_replace_all(text, replace_regex, "")) %>%
  unnest_tokens(word, text, token = "regex", pattern = unnest_regex) %>%
  anti_join(stop_words, by = "word")%>%
  filter(str_detect(word, "[a-z]"))

# This was a fix added after some analysis. It could be added directly
# to the creation of the tweets_tidy variable.
hex_words <-
  tweets_tidy %>%
  filter(str_detect(word, "^[0-9]{2}[0-9a-f]{2}$")) %>%
  select(screen_name, word, created_at)
hex_words

tweets_tidy <-
  tweets_tidy %>%
  anti_join(hex_words, by = "word")

tweets_tidy_summary <-
  tweets_tidy %>%
  group_by(person) %>%
  summarise(total = n()) %>%
  ungroup()
tweets_tidy_summary

words_frequency <-
  tweets_tidy %>%
  # filter(!str_detect(text, "^RT")) %>%
  group_by(person) %>%
  count(word, sort = TRUE) %>%
  left_join(tweets_tidy_summary, by = "person") %>%
  mutate(freq = n / total)
words_frequency

words_frequency <-
  words_frequency %>%
  select(person, word, freq) %>%
  spread(person, freq) %>%
  arrange_at(vars(person1, person2))
words_frequency

words_frequency %>%
  ggplot(aes_string(x = person1, y = person2)) +
  geom_jitter(
    alpha = 0.1,
    size = 2.5,
    width = 0.25,
    height = 0.25
  ) +
  geom_text(aes(label = word), check_overlap = TRUE, vjust = 1.5) +
  scale_x_log10(labels = percent_format()) +
  scale_y_log10(labels = percent_format()) +
  geom_abline(color = "red") +
  labs(title = "Relative Word Frequency")

#'
#' Which words are most likely to be used by one person compared to the other?
#'
#+ include = FALSE
calculate_logratio <- function(person1, person2) {
  log(person1 / person2)
}

person1_quo <- quo(person1)
person2_quo <- quo(person2)
#'
#'
#'
# Filter out replies because they would make up a disproportional share of the
# top results.
# Chenge names before log() in order to perform vectorized operation
# without using quosures.
word_ratios <-
  tweets_tidy %>%
  filter(!str_detect(word, "^@")) %>%
  count(word, person) %>%
  filter(sum(n) >= 10) %>%
  ungroup() %>%
  spread(person, n, fill = 0) %>%
  setNames(c("word", "person1", "person2")) %>%
  mutate_if(is.numeric, funs((. + 1) / sum(. + 1))) %>%
  mutate(logratio = log(person1 / person2)) %>%
  setNames(c("word", person1, person2, "logratio")) %>%
  arrange(desc(logratio))
word_ratios

# These words are the most and least likely to be tweeted by either person.
word_ratios %>% arrange(abs(logratio))
word_ratios %>% arrange(desc(abs(logratio)))

# Not using top_n() because there are lots of ties for Tony.
word_ratios %>%
  group_by(logratio < 0) %>%
  # top_n(15, abs(logratio)) %>%
  arrange(desc(abs(logratio))) %>%
  slice(1:10) %>%
  ungroup() %>%
  mutate(word = reorder(word, logratio)) %>%
  ggplot(aes(word, logratio, fill = logratio < 0)) +
  geom_col() +
  coord_flip() +
  labs(
    x = NULL,
    y = str_c("log odds ratio (", person1, " / ", person2, ")"),
    title = "Words Most Unique to Each Person"
  ) +
  scale_fill_discrete(name = "", labels = persons)

#'
#' Which words have have been used more and less frequently over time?
#'
# Not using count() because the explicitness of group_by()
# followed by summary() is preferred. Also, count() gives
# no option for variable name (defaults to `n`, so the
# group_by()/summary() combo offers more fliexibility.
if(min(tweet_times$months_elapsed) > 3) {
  timefloor <- "month"
} else if (min(tweet_times$days_elapsed) > 15) {
  timefloor <- "week"
} else if (min(tweet_times$hours_elapsed) > 3) {
  timefloor <- "hour"
} else {
  timefloor <- "minute"
}

words_by_time <-
  tweets_tidy %>%
  filter(!str_detect(word, "^@")) %>%
  mutate(time_floor = floor_date(timestamp, unit = timefloor)) %>%
  # count(time_floor, person, word) %>%
  group_by(time_floor, person, word) %>%
  summarise(n = n()) %>%
  ungroup() %>%
  group_by(person, time_floor) %>%
  mutate(time_total = sum(n)) %>%
  group_by(word) %>%
  mutate(word_total = sum(n)) %>%
  ungroup() %>%
  rename(count = n) %>%
  filter(word_total > 30)
words_by_time

words_by_time_nested <-
  words_by_time %>%
  nest(-word, -person)
words_by_time_nested

library("purrr")
words_by_time_models <-
  words_by_time_nested %>%
  mutate(
    models = map(data, ~ glm(cbind(count, time_total) ~ time_floor, .,
                             family = "binomial"))
  )
words_by_time_models

library("broom")
words_by_time_models_slopes <-
  words_by_time_models %>%
  unnest(map(models, tidy)) %>%
  filter(term == "time_floor") %>%
  mutate(adjusted_p_value = p.adjust(p.value))

words_by_time_models_slopes_top <-
  words_by_time_models_slopes %>%
  # filter(adjusted_p_value < 0.1)
  group_by(person) %>%
  # top_n(5, adjusted_p_value)
  arrange(adjusted_p_value) %>%
  slice(1:3) %>%
  ungroup()
words_by_time_models_slopes_top

# Setting more than one guide_legend() to NULL does not work.
words_by_time %>%
  inner_join(words_by_time_models_slopes_top, by = c("word", "person")) %>%
  # filter(person == person2) %>%
  ggplot(aes(x = time_floor, y = count / time_total)) +
  geom_line(aes(color = word), size = 1.5) +
  scale_y_continuous(labels = percent_format()) +
  guides(color = guide_legend(title = NULL)) +
  # theme(legend.title = element_blank()) +
  theme(legend.position = "bottom") +
  labs(x = NULL, y = NULL, title = "Largest Changes in Word Frequencey") +
  facet_wrap(~ person, ncol = 1, scales = "free")

#'
#' # Tweet Popularity
#'
#' How often do the original tweets get liked/favorited/retweeted?
#'

tweets_tidy_author <-
  tweets %>%
  filter(!str_detect(text, "^(RT|@)")) %>%
  mutate(text = str_replace_all(text, replace_regex, "")) %>%
  unnest_tokens(word, text, token = "regex", pattern = unnest_regex) %>%
  anti_join(stop_words, by = "word")

# The rtweets package returns different columns that the twitteR package.
# In a rtweets dataframe, status_id is analogous to id.
# Also retweet_count is analogous to retweets and favorite_count is
# analogous to favorites.
pop_totals <-
  tweets_tidy_author %>%
  group_by(person, status_id) %>%
  summarise(
    rts = sum(retweet_count),
    favs = sum(favorite_count)
  ) %>%
  group_by(person) %>%
  summarise(
    uses = n(),
    rts_total = sum(rts),
    favs_total = sum(favs),
    rts_max = max(rts),
    favs_max = max(favs),
    rts_avg = round(mean(rts), 2),
    favs_avg = round(mean(favs), 2),
    rts_median = median(rts),
    favs_median = median(favs)
  ) %>%
  ungroup()
pop_totals

words_by_pop <-
  tweets_tidy_author %>%
  group_by(status_id, word, person) %>%
  summarise(
    rts = first(retweet_count),
    favs = first(favorite_count)
  ) %>%
  group_by(person, word) %>%
  summarise(
    # uses = n(),
    rts_median = median(rts),
    favs_median = median(favs)
  ) %>%
  left_join(
    # pop_totals %>% select(person, rts_total, favs_total),
    pop_totals %>% select(person),
    by = "person"
  ) %>%
  filter(rts_median != 0 | favs_median != 0) %>%
  ungroup()
words_by_pop

viz_rts <-
  words_by_pop %>%
  group_by(person) %>%
  # top_n(10, rts_median) %>%
  arrange(desc(rts_median)) %>%
  slice(1:10) %>%
  arrange(rts_median) %>%
  ungroup() %>%
  mutate(word = factor(word, unique(word))) %>%
  ggplot(aes(x = word, y = rts_median)) +
  geom_col(aes(fill = person)) +
  theme(legend.position = "none") +
  facet_wrap(~ person, ncol = 2, scales = "free") +
  coord_flip() +
  labs(x = NULL, y = NULL, title = "Words with Highest Median # of RTs")

viz_favs <-
  words_by_pop %>%
  group_by(person) %>%
  # top_n(10, rts_median) %>%
  arrange(desc(favs_median)) %>%
  slice(1:10) %>%
  arrange(favs_median) %>%
  ungroup() %>%
  mutate(word = factor(word, unique(word))) %>%
  ggplot(aes(x = word, y = favs_median)) +
  geom_col(aes(fill = person)) +
  theme(legend.position = "none") +
  facet_wrap(~ person, ncol = 2, scales = "free") +
  coord_flip() +
  labs(x = NULL, y = NULL, title = "Words with Highest Median # of Favorites")

library("gridExtra")
grid.arrange(viz_rts, viz_favs, nrow = 2)

#'
#'
#'
#+ include = FALSE, eval = FALSE
words_by_pop_tidy <-
  words_by_pop %>%
  gather(key, value, -person, -word) %>%
  separate(key, c("type", "calc"), sep = "_")
words_by_pop_tidy

# The ordering may not be exactly as intended due to multiple types.
words_by_pop_tidy %>%
  filter(calc == "median") %>%
  group_by(person, type) %>%
  # top_n(10, rts_median) %>%
  arrange(type, desc(value)) %>%
  slice(1:10) %>%
  arrange(type, value) %>%
  ungroup() %>%
  mutate(word = factor(word, unique(word))) %>%
  ggplot(aes(x = word, y = value)) +
  geom_col(aes(fill = person)) +
  theme(legend.position = "none") +
  facet_wrap(
    type ~ person,
    nrow = 2,
    ncol = 2,
    scales = "free"
  ) +
  coord_flip() +
  labs(x = NULL, y = NULL, title = "Words with Highest Median # of RTs/Favorites")
#'
#' # Sentiment Analysis
#'
#' What is the sentiment (i.e. "tone") of the tweets?
#'
nrc <-
  sentiments %>%
  filter(lexicon == "nrc") %>%
  select(word, sentiment)

sentiment_totals <-
  tweets_tidy %>%
  group_by(person) %>%
  mutate(total_words = n()) %>%
  ungroup() %>%
  distinct(status_id, person, total_words)
sentiment_totals

sentiments_by_word <-
  tweets_tidy %>%
  inner_join(nrc, by = "word") %>%
  count(sentiment, status_id) %>%
  ungroup() %>%
  complete(sentiment, status_id, fill = list(n = 0)) %>%
  inner_join(sentiment_totals, by = "status_id") %>%
  group_by(person, sentiment, total_words) %>%
  summarize(words = sum(n)) %>%
  ungroup()
sentiments_by_word

sentiments_by_word %>%
  mutate(freq = round(words / total_words, 4)) %>%
  select(-words, -total_words) %>%
  spread(person, freq) %>%
  setNames(c("sentiment", "person1", "person2")) %>%
  mutate(sentiment_diff = person1 - person2) %>%
  setNames(c("sentiment", person1, person2, "sentiment_diff")) %>%
  arrange(sentiment_diff)

sentiment_differences <-
  sentiments_by_word %>%
  group_by(sentiment) %>%
  do(tidy(poisson.test(.$words, .$total_words))) %>%
  ungroup()
sentiment_differences

sentiment_differences %>%
  mutate(sentiment = reorder(sentiment, estimate)) %>%
  # mutate_each(funs(. - 1), estimate, conf.low, conf.high) %>%
  mutate_at(vars(estimate, conf.low, conf.high), funs(. - 1)) %>%
  ggplot(aes(x = estimate, y = sentiment)) +
  geom_point() +
  geom_errorbarh(aes(xmin = conf.low, xmax = conf.high), linetype = "solid") +
  geom_vline(aes(xintercept = 0)) +
  scale_x_continuous(labels = percent_format()) +
  labs(
    x = "% increase",
    y = NULL,
    title = str_c("Sentiment Analysis of ", person1, " and ", person2)
  )

word_ratios %>%
  inner_join(nrc, by = "word") %>%
  # filter(!sentiment %in% c("positive", "negative")) %>%
  mutate(sentiment = reorder(sentiment,-logratio),
         word = reorder(word, -logratio)) %>%
  group_by(sentiment) %>%
  # top_n(5, abs(logratio)) %>%
  arrange(abs(logratio)) %>%
  slice(1:5) %>%
  ungroup() %>%
  ggplot(aes(x = word, y = logratio, fill = logratio < 0)) +
  geom_bar(stat = "identity") +
  scale_fill_manual(
    name = NULL,
    labels = persons,
    values = hue_pal()(2)
  ) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
  theme(legend.position = "bottom") +
  labs(
    x = NULL,
    y = str_c("log odds ratio (", person1, " / ", person2, ")"),
    title = "Most Influential Words Contributing to Sentiment Differences"
  ) +
  facet_wrap( ~ sentiment, scales = "free", nrow = 2)

#'
#'
#' # Conclusion
#'
#' That's it!
#'

#'
#'
