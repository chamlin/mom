xquery version '1.0-ml';

module namespace mom = 'http://marklogic.com/support/map-of-maps';

(: ======= sql:result to mom stuff ======= :)

declare function mom:kids-in-order ($mom) {
    for $kid in map:get ($mom, 'kids')
    order by map:get ($kid, 'position')
    return $kid
};

declare function mom:dump-mom ($mom) {
    mom:dump-mom ('', $mom)
};

declare function mom:dump-mom ($indent, $mom) {
    let $attr :=
        for $key in map:keys ($mom) 
        where fn:not ($key = ('column', 'content', 'kids'))
        return fn:concat ('(', $key, '=',  fn:string (map:get ($mom, $key)), ')')
    return 
        ('map-of-maps: '||$indent||map:get ($mom, 'column') ||' = '||map:get ($mom, 'content') || ': ' || fn:string-join ($attr, ' '))
    ,
    for $kid in mom:kids-in-order ($mom)
    return mom:dump-mom ($indent||'    ', $kid)
};

declare function mom:transform ($mom as map:map, $config as map:map) {
    let $before := map:get ($config, 'before')
    let $after := map:get ($config, 'after')
    let $_before := xdmp:apply (map:get ($config, 'before'), $mom, $config)
    let $_under := 
        for $kid in mom:kids-in-order ($mom)
        return mom:transform ($kid, $config)
    let $_after := xdmp:apply (map:get ($config, 'after'), $mom, $config)
    return $mom
};

declare function mom:get-matching-kid ($column, $content, $kids) {
    let $trace := xdmp:trace('map-of-maps', 'checking for '||$column||' = '||$content)
    let $kid-string := fn:string-join (($kids ! xdmp:describe (map:get (., 'content'))), ' - ')
    let $trace := xdmp:trace('map-of-maps', 'checking in '||$kid-string)
    return
    (for $kid in $kids 
    let $trace := xdmp:trace('map-of-maps', '    checking against '||map:get ($kid, 'content'))
    where fn:string(map:get ($kid, 'content')) eq fn:string ($content)
    return $kid)[1]
};

declare function mom:add-to-map-of-maps ($map, $columns, $values) {
    if (fn:exists (map:get ($map, 'column'))) then () else (
        map:put ($map, 'column', '_root'),
        map:put ($map, 'content', '_root')
    ),
    if (fn:count ($values) = 0 or fn:count ($columns) = 0) then () else (: add :)
    let $_trace := xdmp:trace('map-of-maps', "add - working in: "||map:get ($map, 'column')||' = '||map:get ($map, 'content'))
    let $_trace := xdmp:trace('map-of-maps', "add - working on: "||$columns[1]||' = '||$values[1])
    let $current-kids := map:get ($map, 'kids')
    let $current-kid := mom:get-matching-kid ($columns[1], $values[1], $current-kids)
    let $kid-to-use := 
        if (fn:exists ($current-kid)) then
            $current-kid 
        else 
            let $new-cell := mom:new-cell ($columns[1], $values[1], fn:count ($current-kids)+1)
            let $trace := xdmp:trace('map-of-maps', "new cell: "||xdmp:describe ($new-cell, (), ()))
            let $_insert := map:put ($map, 'kids', ($current-kids, $new-cell))
            return $new-cell
    return mom:add-to-map-of-maps ($kid-to-use, fn:subsequence ($columns, 2), fn:subsequence ($values, 2))
};

declare function mom:new-cell ($column, $value, $position) {
    map:new((
        map:entry ('content', $value),
        map:entry ('column', $column),
        map:entry ('position', $position)
        (: map:entry ('kids', ()) :)
    ))
};

(: ======= mom to table stuff ======= :)

declare variable $config := map:new ((
    map:entry ('kids', function ($root) { mom:kids-in-order ($root) }),
    map:entry ('content', function ($root) {
            let $content := map:get ($root, 'content')
            let $color := map:get ($root, 'cell-color')
            return (
                if (fn:exists ($color)) then attribute { 'style' } { 'background-color: '||$color } else (),
                $content
            )
        }
    )
));

declare function mom:get-nodes ($config as map:map, $roots as map:map*, $id) {
    for $root in $roots
    return (
        if (xdmp:apply (map:get ($config, 'identity'), $root) eq $id) then
            $root
        else ()
        ,
        mom:get-nodes ($config, xdmp:apply (map:get ($config, 'kids'), $root), $id)
    )
};

(: recurse, assign heights and save them back up as _height :)
declare function mom:assign-heights ($config, $root as map:map) {
    let $kids := xdmp:apply (map:get ($config, 'kids'), $root)
    let $height :=
        if (fn:exists ($kids)) then
            fn:sum (for $kid in $kids return mom:assign-heights ($config, $kid))
        else 1
    let $_store := map:put ($root, '_height', $height) 
    return $height
};

(: recurse, assign heights and bubble them back up and sum :)
declare function mom:get-height ($config as map:map, $root as map:map) {
    let $kids := xdmp:apply (map:get ($config, 'kids'), $root)
    return
        if (fn:exists ($kids)) then
            fn:sum (for $kid in $kids return mom:get-height ($config, $kid))
        else 1
};

declare function mom:fire-item-for-row ($config, $first-row, $last-row, $item, $row, $height-offset, $tr-started) { 
    let $x := attribute { 'debug-rows' } { $first-row||' - '||$row||' - '||$last-row||', '||$tr-started }
    let $current-content := <td rowspan='{mom:get-height ($config, $item)}'>{$x, xdmp:apply (map:get ($config, 'content'), $item)}</td>
    let $current-kids := xdmp:apply (map:get ($config, 'kids'), $item)
    let $blank-cell := if (fn:exists ($current-kids)) then <td label='{map:get ($item, "label")}'/> else ()
    let $start-tr :=
        if (fn:not ($tr-started) and $row = $height-offset + 1) then fn:true()
        else fn:false()
    let $recursion-content := 
        if (fn:exists ($current-kids)) then mom:process-kids ($config, $current-kids, $row, $height-offset, $tr-started or $start-tr) else ()
    return
        if ($start-tr) then 
            <tr row='{$row}'>{ $current-content, $recursion-content }</tr>
        else if ($row = $first-row) then
            ($current-content, $recursion-content)
        else ($recursion-content)
};

declare function mom:process-kids ($config, $kids, $row, $height-offset, $tr-started) {
    for $kid at $i in $kids
    (: first row for this kid = 1 + offset + preceding; last is first + height - 1 :)
    let $preceding-kid-height := fn:sum ((for $pre in $kids[1 to $i - 1] return mom:get-height ($config, $pre)))
    let $first-row := 1 + $height-offset + $preceding-kid-height
    let $last-row := $first-row + mom:get-height ($config, $kid) - 1
    where ($first-row <= $row) and ($row <= $last-row)
    return mom:fire-item-for-row ($config, $first-row, $last-row, $kid, $row, $height-offset + $preceding-kid-height, $tr-started)
};

(: here is where you get your table :)
declare function mom:table ($map as map:map*, $columns, $caption) {
    <table border="1">{
        if ($caption) then <caption>{$caption}</caption> else (),
        <tr>{$columns ! <th>{.}</th>}</tr>,
        for $row in mom:kids-in-order ($map) return mom:table-row ($row) 
        }
    </table>
};

(: top level row call; rows is a bunch of rows, root of the mom for the row :)
declare function mom:table-row ($root) {
    for $row in 1 to mom:get-height ($config, $root)
    return mom:process-kids ($config, $root, $row, 0, fn:false())
};

declare function mom:get-values ($config as map:map, $roots as map:map*, $value-name) {
    mom:_get-values ($config, $roots, $value-name, fn:true())
};

declare function mom:get-values ($config as map:map, $roots as map:map*, $value-name, $recurse) {
    mom:_get-values ($config, $roots, $value-name, $recurse)
};

declare function mom:_get-values ($config as map:map, $roots as map:map*, $value-name, $recurse as xs:boolean) {
    for $root in $roots
    return (
        xdmp:apply (map:get ($config, $value-name), $root),
        if ($recurse) then 
            mom:_get-values ($config, xdmp:apply (map:get ($config, 'kids'), $root), $value-name, $recurse)
        else ()
    )
};


