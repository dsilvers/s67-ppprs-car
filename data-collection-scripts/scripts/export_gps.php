<?php

mysql_connect("localhost", "root", "");
mysql_select_db("car");


class dataset {
    var $lat = false;
    var $lon = false;
    var $status = false;

    function done()
    {
        if($this->lat && $this->lon && $this->status && $this->status == 1)
            return true;

        return false;
    }
}


$result = mysql_query("SELECT timestamp, field, value FROM data_raw WHERE dataset = 'ALL' ORDER BY timestamp ASC");
print mysql_num_rows($result) . " rows\n";


$last = 0;
while(list($timestamp, $field, $value) = mysql_fetch_row($result))
{
    if($last != $timestamp)
        $dataset = new dataset();

    if($field == "gps_lat")
        $dataset->lat = $value;
    else if($field == "gps_lon")
        $dataset->lon = $value;
    else if($field == "gps_status")
        $dataset->status = $value;

    var_dump($dataset);

    if($dataset->done())
    {
        echo "$dataset->lat,$dataset->lon,$dataset->status\n";
    }
    $last = $timestamp;
}
