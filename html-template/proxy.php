<?php
// original from http://xmlrpcflash.mattism.com/proxy_info.php
const WAIT=2;
const MAXPOSTDATASIZE=1024;

sleep(WAIT);

$url = $_GET['url'];
if(FALSE == strstr($url, "www.google.com/loc/json")){ exitWithMessage(403, "undef"); }

if(strlen($HTTP_RAW_POST_DATA) > MAXPOSTDATASIZE){ exitWithMessage(502, "bad gateway"); }

$header[] = "Content-type: text/xml";
$header[] = "Content-length: ".strlen($HTTP_RAW_POST_DATA);

$ch = curl_init( $_GET['url'] );
curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
curl_setopt($ch, CURLOPT_TIMEOUT, 6);
curl_setopt($ch, CURLOPT_HTTPHEADER, $header);

if ( strlen($HTTP_RAW_POST_DATA)>0 ){
 curl_setopt($ch, CURLOPT_POST, 1);
 curl_setopt($ch, CURLOPT_POSTFIELDS, $HTTP_RAW_POST_DATA);
}

$response = curl_exec($ch);
$response_headers = curl_getinfo($ch);

if (curl_errno($ch)) {
  exitWithMessage(502, curl_error($ch));
}
else
{
 curl_close($ch);
 header('Content-type: ' . $response_headers['content-type']);
 print substr($response, 0, 5120);
}


function exitWithMessage($code, $message)
{
   header("Content-Type: text/html; charset=iso-8859-1");
   header($message, true, (int)$code);
?><!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html><head>
<title><?= $code ?>:<?= $message ?></title>
</head><body>
<?= $message ?>
</body></html>
<?
}
