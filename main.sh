#!/bin/bash

source settings.sh

hms_to_hours() {
    echo "$1" | awk -F: '{ print (($1 * 3600) + ($2 * 60) + $3) / 3600 }'
}

get_value_from_last_datapoint() {
    curl -s https://www.beeminder.com/api/v1/users/$USERNAME/goals/"$1"/datapoints.json\?auth_token\=$AUTHENTICATION_TOKEN | jq ".[0].$2" | tr -d '"'
}

create_empty_datapoint() {
    goal_name=$1
    daystamp=$2
    comment=$3
    curl -X POST https://www.beeminder.com/api/v1/users/$USERNAME/goals/$goal_name/datapoints.json \
    -d auth_token=$AUTHENTICATION_TOKEN \
    -d daystamp=$daystamp \
    -d comment="$comment" \
    -d value=0.0 
}

update_datapoint() {
    id_last_datapoint=$(get_value_from_last_datapoint $1 id)
    value_last_datapoint=$(get_value_from_last_datapoint $1 value)
    if (( $(echo "$2 > $value_last_datapoint" | bc -l) ))
    then
        curl -X PUT https://www.beeminder.com/api/v1/users/$USERNAME/goals/$1/datapoints/"$id_last_datapoint".json \
        -d auth_token=$AUTHENTICATION_TOKEN \
        -d value=$2
    else
        echo "Not updating data for $1, since new value $2 is lower than the old current value $value_last_datapoint. \
            Updating might trigger an accidental recommit."
    fi
}

get_information_goal() {
        goal=$1
        jq_filter=$2
        curl "$BEEMINDER_URL_START""$goal".json\?auth_token\="$AUTHENTICATION_TOKEN"\&datapoints\=false |
        jq "$2"
}     

get_daystamp_today() {
    date --date "5 hours ago" +%Y%m%d
}

check_if_new_datapoint_needs_to_be_created() {
    tag=$1
    no_difference_in_dates_detected=false
    for i in {1..5}
    do
        if (( i > 1 ))
        then
            echo "$i"". check if dates match"
        fi
        date_day=$(get_daystamp_today)
        echo "Date 5 hours ago: $date_day"
        date_last_datapoint=$(get_value_from_last_datapoint $tag daystamp)
        echo "Date last datapoint: $date_last_datapoint"
        if [[ $date_day == $date_last_datapoint ]] || (( ${#date_last_datapoint} < 3 ))
        then
            no_difference_in_dates_detected=true
            break
        else
            echo Dates do not match!
            echo date_day: $date_day
            echo date_last_datapoint: $date_last_datapoint
        fi
        sleep 5
    done
    if $no_difference_in_dates_detected
    then
        return 1
    else
        return 0
    fi
}

get_day_of_the_week() {
    date +%u
}

if [[ "$1" != 'only_source' ]]
then
    while true
    do
        for e in $TAGS
        do 
            if check_if_new_datapoint_needs_to_be_created $e
            then
                echo "Creating Datapoint"
                daystamp=$(get_daystamp_today)
                create_empty_datapoint $e $daystamp
            fi
            echo $e
            time_with_seconds=$(eval 'echo "   "; timew su $(date --date "301 minutes ago" +%Y-%m-%d)T05:00:00 - tomorrow '$e' | tail -2 | head -1 | { read first rest; echo $first; }')
            time_without_seconds=${time_with_seconds::-3}
            hours="$(hms_to_hours $time_with_seconds)"
            hours=${hours/,/.}
            break_time_hours_deficite=$(awk 'BEGIN {print'" $(zsh -ic 'btime') / -60"'}')
            break_time_hours_deficite=${break_time_hours_deficite/,/.}
            echo "break_time_hours_deficite: " "$break_time_hours_deficite"
            if (( $(echo "$break_time_hours_deficite > 0" |bc -l) ))
            then
                hours_without_break_time=$( awk 'BEGIN {print '"$hours - $break_time_hours_deficite"'}' )
            else
                hours_without_break_time=$hours
            fi
            hours_without_break_time=${hours_without_break_time/,/.}
            echo "hours_without_break_time: " "$hours_without_break_time"
            echo "Worked $hours_without_break_time h up until now."
            if ((  $(echo "$hours_without_break_time > 0" |bc -l) ))
            then
                update_datapoint $e $hours_without_break_time
            fi
            printf '\n\n'
        done
        sleep $SLEEP_TIME_SECONDS
    done
fi
