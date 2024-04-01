# mom

xquery, for map-of-maps of tabular results, create an html table.

Just pass in sparql results, column heads.

Config for autogrouping or nah.

Next:  add transform hooks.

internal attributes will start with \_. For example, \_height and \_start.  \_kids is children array. \_root attribute notes root of mom
\_content

Example:

```
import module namespace mom = 'http://marklogic.com/support/map-of-maps' at '/lib/mom.xqy';
let $columns := ('dbName','mergePriority','mergeMaxSize','mergeMinSize','mergeMinRatio','mergeTimestamp','retainUntilBackup')

let $results := (
    map:map (
        <map:map xmlns:map="http://marklogic.com/xdmp/map" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <map:entry key="retainUntilBackup">
                <map:value xsi:type="xs:boolean">false</map:value>
            </map:entry>
            <map:entry key="mergeMinSize">
                <map:value xsi:type="xs:unsignedInt">1024</map:value>
            </map:entry>
            <map:entry key="dbName">
                <map:value xsi:type="xs:string">DB-A</map:value>
            </map:entry>
            <map:entry key="mergeMaxSize">
                <map:value xsi:type="xs:unsignedInt">32768</map:value>
            </map:entry>
            <map:entry key="mergeTimestamp">
                <map:value xsi:type="xs:long">0</map:value>
            </map:entry>
            <map:entry key="mergePriority">
                <map:value xsi:type="xs:string">lower</map:value>
            </map:entry>
            <map:entry key="mergeMinRatio">
                <map:value xsi:type="xs:unsignedInt">1</map:value>
            </map:entry>
        </map:map>
    ),
    map:map (
        <map:map xmlns:map="http://marklogic.com/xdmp/map" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xs="http://www.w3.org/2001/XMLSchema">
            <map:entry key="retainUntilBackup">
                <map:value xsi:type="xs:boolean">false</map:value>
            </map:entry>
            <map:entry key="mergeMinSize">
                <map:value xsi:type="xs:unsignedInt">1024</map:value>
            </map:entry>
            <map:entry key="dbName">
                <map:value xsi:type="xs:string">DB-B</map:value>
            </map:entry>
            <map:entry key="mergeMaxSize">
                <map:value xsi:type="xs:unsignedInt">32768</map:value>
            </map:entry>
            <map:entry key="mergeTimestamp">
                <map:value xsi:type="xs:long">0</map:value>
            </map:entry>
            <map:entry key="mergePriority">
                <map:value xsi:type="xs:string">normal</map:value>
            </map:entry>
            <map:entry key="mergeMinRatio">
                <map:value xsi:type="xs:unsignedInt">2</map:value>
            </map:entry>
        </map:map>
    )
)

let $config := map:new ((map:entry ('columns', $columns), map:entry ('caption', 'Merge parameters for databases in collection')))
let $mom := mom:result-to-mom ($config, $results)
let $table := mom:table ($mom)
return $table
```

returns

```
<table border="1">
    <caption>Merge parameters for databases in collection</caption>
    <tr>
        <th>dbName</th>
        <th>mergePriority</th>
        <th>mergeMaxSize</th>
        <th>mergeMinSize</th>
        <th>mergeMinRatio</th>
        <th>mergeTimestamp</th>
        <th>retainUntilBackup</th>
    </tr>
    <tr>
        <td rownum="1">DB-A</td>
        <td rownum="1">lower</td>
        <td rownum="1">32768</td>
        <td rownum="1">1024</td>
        <td rownum="1">1</td>
        <td rownum="1">0</td>
        <td rownum="1">false</td>
    </tr>
    <tr>
        <td rownum="2">DB-B</td>
        <td rownum="2">normal</td>
        <td rownum="2">32768</td>
        <td rownum="2">1024</td>
        <td rownum="2">2</td>
        <td rownum="2">0</td>
        <td rownum="2">false</td>
    </tr>
</table>
```

