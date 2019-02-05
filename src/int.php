<?php

$directory	= 'src/kernel';
$infoRegex	= '/InterruptInfo[\\s]+((?:[\\w]+[, \\t]*)+)/';
$infoRegex2	= '/([\w]+)[, \t]*/';

$int_start = 0x80;
$int_current = $int_start;

$out_interrupts = [];

function ParseFile($file)
{
	global $directory, $infoRegex, $infoRegex2;
	global $int_current;

	$int_id_current = 0;

	//echo "Filename: $file\n";
	$content = file_get_contents($file);
	preg_match_all($infoRegex, $content, $matches);
	if(count($matches) == 0 || count($matches[1]) == 0)
		return;

	$functions = preg_split('[,\\W]', $matches[1][0], -1, PREG_SPLIT_NO_EMPTY);
	//echo "$functions\n";
	//var_dump($functions);

	$intName = strtoupper(basename($file, ".asm"));
	echo "INT_API_" . $intName . " equ 0x" . dechex($int_current++) . "\n";

	for($a = 1; $a < count($functions); $a++)
	{
		//var_dump(preg_split('/([a-z][A-Z])/', $functions[$a], -1, PREG_SPLIT_DELIM_CAPTURE));

		$v = strtoupper(preg_replace("/([a-z])([A-Z])/", "\\1_\\2", $functions[$a]));
		//var_dump($v);
		echo "$v equ 0x" . dechex($a-1) . "\n";

		/*$functionName = implode("_", preg_split('[_]|([a-z][A-Z])', $functions[$a]));
		//echo "API_" . $intName . "_" . $functionName . "\n";
		echo "API_" . $functionName . "\n";

		$int_id_current++;*/
	}

	echo "\n";

	/*var_dump($matches);
	return;

	preg_match_all($infoRegex2, $matches[1][0], $matches);

	$functions = array_shift($matches[1]);*/
}

function ScanDirectory($directory)
{
	$files = scandir($directory);
	foreach ($files as $file) 
	{
		$path = "$directory/$file";
		if(is_dir($path) && $file != "." && $file != "..")
		{
			ScanDirectory($path);
			continue;
		}
		else if(strpos($file, ".asm") != strlen($file)-4)
		{
			continue;
		}
	
		//echo "Filename: $path\n";
	
		ParseFile($path);
	}
}

ScanDirectory($directory)

?>