<?php

$directory	= 'src/kernel/int';
$infoRegex	= '/InterruptInfo[\\s]+((?:[\\w]+[, \\t]*)+)/';
$infoRegex2	= '/([\w]+)[, \t]*/';

function ParseFile($file)
{
	global $directory, $infoRegex, $infoRegex2;

	echo "Filename: $file\n";
	$content = file_get_contents($directory . "/" . $file);
	preg_match_all($infoRegex, $content, $matches);
	preg_match_all($infoRegex2, $matches[1][0], $matches);

	$functions = array_shift($matches[1]);
}

$interrupts = scandir($directory);
foreach ($interrupts as $file) 
{
	if(strpos($file, ".asm") != strlen($file)-4)
		continue;

	ParseFile($file);
}

?>