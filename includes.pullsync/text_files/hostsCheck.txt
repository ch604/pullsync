<html>
<head>
<title>Migration Test Page</title>
<style>
body {text-align:center;font-size:20px;line-height:25px;font-weight:bold;font-family:Arial,sans-serif;background-color:#2AC4F3;}
.t {font-size:50px;line-height:50px;padding:21px;color:#FFFFFF;}
.i {width:50%;margin-left:25%;text-align:left;}
</style>
</head>
<body>
<?php
echo "<div class='t'>This is the new server!</div>";

$baseurl=$_SERVER['SERVER_NAME'];

echo "You're accessing: " . $baseurl . "<br>";

echo "This server's Ip: " . $_SERVER['SERVER_ADDR'] . "<br>";

echo "This server's hostname: ";
if (function_exists('gethostname')) {
  echo gethostname() ;
} else {
  //for php < 5.3
  echo php_uname('n');
}
echo "<br><br>";

echo "This page is unique to the destination of your migration. If you are seeing it, you have correctly modified your hosts file, and are ready to test this domain on the target server.<br><br>";

//get baseurl to direct customer to testing info
echo "Test this domain here: <a href=http://" . $baseurl . ">" . $baseurl . "</a>";

?>
</body>
</html>

