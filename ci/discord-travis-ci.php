<?php

/*
* CONFIG
*/
$COLOR_PASS = 3779158; #39AA56
$COLOR_FAIL = 14370117; #DB4545
$COLOR_IN_PROGRESS = 15588927; #EDDE3F
$COLOR_CANCEL = 10329501; #9D9D9D
$DISCORD_WEBHOOK_URL = '';

if ($_SERVER['REQUEST_METHOD'] != 'POST') {
  header('HTTP/1.0 405 Method Not Allowed');
  echo "Only POST requests allowed\n";
  exit();
}

if ($_SERVER['CONTENT_TYPE'] != 'application/x-www-form-urlencoded') {
  header('HTTP/1.0 415 Unsupported Media Type');
  echo "I only accept application/x-www-form-urlencoded data\n";
  exit();
}

$fullPostData = $_POST['payload'];

$travisApiConfig = json_decode(file_get_contents('https://api.travis-ci.org/config'));
$publicKey = $travisApiConfig->config->notifications->webhook->public_key;
$signature = base64_decode($_SERVER['HTTP_SIGNATURE']);
if (openssl_verify($fullPostData, $signature, $publicKey) != 1) {
  header('HTTP/1.0 401 Access Denied');
  exit();
}

if ($fullPostData == '') {
  header('HTTP/1.0 400 Bad request');
  echo "No data submitted\n";
  exit();
}

$data = json_decode($fullPostData, true);

if ($data === null) {
  header('HTTP/1.0 400 Bad request');
  echo "JSON cannot be decoded\n";
  exit();
}

$result_string = 'result_message';
$time = 'finished_at';

if ($data[$result_string] === null) {
  $result_string = 'status_message';
}

switch ($data[$result_string]) {
  case "Pending":
    $color = $COLOR_IN_PROGRESS;
    $time = 'started_at';
    break;
  case "Passed":
  case "Fixed":
    $color = $COLOR_PASS;
    break;
  case "Broken":
  case "Failed":
  case "Still Failing":
    $color = $COLOR_FAIL;
    break;
  case "Canceled":
    $color = $COLOR_CANCEL;
}

$payload = array(
  'username' => 'Travis CI',
  'avatar_url' => 'https://csgottt.com/travis.png',
  'embeds' => array(
    array(
      'color' => $color,
      'author' => array(
        'name' => 'Build #' . $data['number'] . ' ' . $data[$result_string] . ' - ' . $data['author_name'],
        'url' => $data['build_url']
      ) ,
      'title' => '[' . $data['repository']['name'] . ':' . $data['branch'] . ']',
      'url' => getRepoURL($data) ,
      'description' => '[`' . substr($data['commit'], 0, 7) . '`](' . getCommitURL($data) . ') ' . $data['message'],
      'timestamp' => $data[$time]
    )
  )
);

$context = stream_context_create(array(
  'http' => array(
    'method' => 'POST',
    'header' => 'Content-Type: application/json',
    'content' => json_encode($payload)
  )
));

$response = file_get_contents($DISCORD_WEBHOOK_URL, false, $context);

function getRepoURL($data) {
  return 'http://github.com/' . $data['repository']['owner_name'] . '/' . $data['repository']['name'];
}

function getCommitURL($data) {
  return getRepoURL($data) . '/commit/' . $data['commit'];
}

?>
