#!/bin/tcsh

setenv file_buffer 'twitter.html'
setenv log_buffer '.log'
setenv message_buffer '.message'
setenv report_buffer '.report'
setenv linkfile 'savedlinks.txt'
setenv logfile 'logfile.txt'
setenv filterfile 'excludingwords.txt'

begin:
echo
echo 'Welcome! Please select from options below:'
echo '|- q: Quit program'
echo '|- e: Enter new URL'
echo '|- u: Use saved URL'
echo '|- a: Add ignored words'
echo '|- s: Show logfile'
echo '|- g: Generate summary report'
reenter:
echo
echo -n '>> '
set option = $<

switch ($option)
	case q:
		echo 'Exit program...'
		# remove buffers
		rm -f $file_buffer $log_buffer $message_buffer $report_buffer
		exit
	case e:
		# read in link and save to link file
		echo 'Enter twitter link: '
		echo
		echo -n '>> '
		set url = $<
		if (-e $linkfile) then
			if (`grep $url $linkfile | wc -l` == 0) then
				echo $url >> $linkfile
			else
				echo 'URL Exists!'
			endif
		else
			echo $url > $linkfile
		endif
		goto scrape
	case u:
		# get saved link
		echo 'Select a saved URL below:'
		echo '|- 0: Abort!'
		cat $linkfile | awk '{ print "|- "NR": "$0 }'
retry:
		echo
		echo -n '>> '
		set line = $<
		if ($line =~ [0-9]*) then
			if (`cat $linkfile | wc -l` < $line) then
				echo 'Invalid line number!'
				goto retry
			else if ($line == 0) then
				echo 'Aborted...'
				goto begin
			endif
		else
			echo 'Invalid line number!'
			goto retry
		endif
		set url = `cat $linkfile | sed -n $line'p'`
		goto scrape
	case a:
		# read in ingnored words
		echo 'Enter words to be ignored: '
		echo
		echo -n '>> '
		set ignore = $<
		touch $filterfile
		echo $ignore >> $filterfile
		goto begin
	case s:
		# show logfile
		cat $logfile
		goto begin
	case g:
		# generate message summary file
		set file_list = `ls *[0-9]*.txt | sed 's/_report_/_/g' | uniq`
		if (-e $message_buffer) then
			rm $message_buffer
		endif
		touch $message_buffer
		foreach file ($file_list)
			cat $file | sed -n '4,$p' >> $message_buffer
		end
		set messagefile = `echo $message_buffer`
		set reportfile = `echo $report_buffer`
		set topic = 'All recent'
		set format_date = 'Summary'
		goto report
	default:
		echo 'Invalid input!'
		goto reenter
endsw

scrape:
# scrape web page
wget $url -O $file_buffer -o $log_buffer

# create log file
if (! -e $logfile) then
touch $logfile
echo 'twitter messages capture log' >> $logfile
echo 'Date                Location                                  File name     File size' >> $logfile
echo '------------------- ----------------------------------------- ------------- ---------' >> $logfile
endif

# generate variables
set month_array = ( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )
set time = `cat $log_buffer | sed -n '1s/^--\(.*\)--.*$/\1/p'`
set month = `echo $time | awk -F'[ -]' '{ print $2 }'`
set date = `echo $time | awk -F'[ -]' '{ print $3 }'`
set year = `echo $time | awk -F'[ -]' '{ print $1 }'`
set format_date = $month_array[$month]' '$date' '`echo $date | sed 's/01/st/;s/02/nd/;s/03/rd/;s/[0123][0-9]/th/'`' '$year
set topic = `cat $file_buffer | sed -n '/<h2 class="StreamsHero-header">/s/[^>]*>\([^<]*\)<.*/\1/p' | sed 's/&amp;/and/'`
set messagefile = `echo $topic | sed 's/[^a-zA-Z]//g' | tr '[:upper:]' '[:lower:]'`'_'$month$date$year'.txt'
set reportfile = `echo $messagefile | sed 's/_/_report_/'`

# append log file
echo $time | awk '{ printf "%-19s ", $0 }' >> $logfile
cat $log_buffer | sed -n '1s/^--.*--  \(.*\)$/\1/p' | awk '{ printf "%-41s ", $0 }' >> $logfile
echo $file_buffer | awk '{ printf "%-13s ", $0 }' >> $logfile
cat $log_buffer | sed -n '/^Length: /s/.*: \([0-9]*\).*$/\1/p' | awk '{ printf "%-9s\n", $0 }' >> $logfile

# generate message file
echo $format_date' - '$topic' twitter messages' > $messagefile
echo 'Messages' >> $messagefile
echo '--------------------' >> $messagefile
cat $file_buffer | sed -n '/<p class="TweetTextSize.*<\/p>/s/<[^>]*>//gp' | sed 's/http.*$//g;s/[^ ]*\.[^ ]*\.[^ ]*\/[^ ]*//g;s/&[^;]*;//g;s/^[\t ]*//g' >> $messagefile

report:
# generate report file
echo $format_date' - Top 20 words - '$topic' twitter messages' > $reportfile
echo 'Top words           Frequency    Percentage' >> $reportfile
echo '------------------- ------------ ----------' >> $reportfile
set raw_text = `cat $messagefile | sed '1,3d;s/[^a-zA-Z ]//g' | tr '[:upper:]' '[:lower:]'`
set filtered_text = `echo $raw_text`
foreach w (`cat $filterfile`)
	set filtered_text = `echo $filtered_text | sed 's/[^a-zA-Z]'$w'[^a-zA-Z]/ /g'`
end
set word_count = `echo $raw_text | wc -w`
echo $filtered_text | tr ' ' '\n' | sort | sed '/^\s*$/d' | uniq -c | awk '{ print $1" "$2 }' | sort -nr | sed -n '1,20p' | awk -v count="$word_count" '{ printf "%-19s %-12s %.2f%%\n", $2, $1, $1/count*100 }' >> $reportfile

# output report
cat $reportfile

goto begin
