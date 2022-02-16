xquery version '1.0-ml';

module namespace mom = 'http://marklogic.com/support/map-of-maps';

(: ======= sql:result to mom stuff ======= :)


declare function mom:dump-mom ($mom) {
    mom:dump-mom ('', $mom)
};

declare function mom:dump-mom ($indent, $mom) {
    let $attr :=
        for $key in map:keys ($mom) 
        where fn:not ($key = ('_column', '_content', '_kids'))
        return fn:concat ('(', $key, '=',  fn:string (map:get ($mom, $key)), ')')
    return 
        ('map-of-maps: '||$indent||map:get ($mom, '_column') ||' = '||map:get ($mom, '_content') || ' | ' || fn:string-join ($attr, ' '))
    ,
    for $kid in map:get ($mom, '_kids')
    return mom:dump-mom ($indent||'    ', $kid)
};

declare function mom:cell-sig ($mom as map:map) {
    fn:string-join (( '[', map:get ($mom, '_column'), '=', fn:string(map:get ($mom, '_content')), ' (', fn:string (fn:count (map:get ($mom, '_kids'))), ')]' ), '')
    (: fn:string-join (( '[', map:get ($mom, '_column'), '=', fn:string(map:get ($mom, '_content')), ' (', fn:string (map:count (map:get ($mom, '_kids'))), ')]' ), '') :)
};

declare function mom:result-to-mom ($columns, $result) {
    (: init the root :)
    let $mom := mom:new-cell ('_root')
    let $_load := 
        (: should be straight across additions :)
        for $row in $result
        let $trace := xdmp:trace('mom:rtm', 'adding row '||xdmp:describe ($row, (), ()))
        let $values := for $column in $columns return (map:get ($row, $column))
        return mom:result-to-mom_ ($mom, $columns, $values)
    return $mom
};

(: order by each column? :)
declare function mom:result-to-mom_ ($mom, $columns, $values) {
    (: latest row, or column value, or create a new one, if none :)
    if (fn:count ($values) = 0 or fn:count ($columns) = 0) then () else (: add :)
    let $trace := xdmp:trace('mom:rtm', 'adding '||$columns[1]||' = '||$values[1]||'.')
    let $new-kid := mom:add-kid ($mom, $columns[1], $values[1])
    let $latest-kid := mom:latest-kid ($mom)
    let $trace := xdmp:trace('mom:rtm', 'adding cell '||mom:cell-sig ($new-kid)||' to '||mom:cell-sig ($mom))
    let $trace := xdmp:trace('mom:rtm', 'next to consider '||mom:cell-sig ($latest-kid))
    return mom:result-to-mom_ ($latest-kid, fn:subsequence ($columns, 2), fn:subsequence ($values, 2))
};

declare function mom:latest-kid ($mom) {
    map:get ($mom, '_kids')[last()]
};

declare function mom:add-kid ($mom, $column, $content) {
    let $new := mom:new-cell ($column, $content)
    let $_add := map:put ($mom, '_kids', (map:get ($mom, '_kids'), $new))
    return $new
};

declare function mom:new-cell ($column) {
    mom:new-cell ($column, (), ())
};

declare function mom:new-cell ($column, $content) {
    mom:new-cell ($column, $content, ())
};

declare function mom:new-cell ($column, $content, $kids) {
    map:new((
        map:entry ('_column', $column),
        map:entry ('_content', $content),
        map:entry ('_kids', $kids)
    ))
};




(: ======= mom to table stuff ======= :)


