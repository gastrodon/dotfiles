def uniq: reduce .[] as $x ([]; if index([$x]) == null then . + [$x] else . end);

def dm($a; $b):
  if ($a | type) == "object" and ($b | type) == "object" then
    reduce ($b | keys_unsorted[]) as $k ($a;
      .[$k] = (if has($k) then dm(.[$k]; $b[$k]) else $b[$k] end))
  elif ($a | type) == "array" and ($b | type) == "array" then ($a + $b) | uniq
  elif $b == null and $a != null then $a
  else $b
  end;

if $mode == "settings" then
  reduce .[] as $x ({}; dm(.; $x))
else
  reduce .[] as $x ({}; . + ($x.mcpServers // {}))
end
