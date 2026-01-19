> "Ah ? Une petite aversion pour le travail manuel ?" Le docteur haussa un sourcil.
> "Compréhensible, mais mal placé. On devrait chérir ces tâches terre-à-terre qui gardent le corps occupé mais laissent l'esprit et le cœur libres." (1)
>
> <cite>Tad Williams, <em>The Dragonbone Chair</em></cite>

Notre petite VM peut représenter trois types de valeurs en ce moment : les nombres, les Booléens, et `nil`. Ces types deux choses importantes en commun : ils sont immuables et ils sont petits. Les nombres sont les plus grands, et ils tiennent toujours dans deux mots de 64 bits. C'est un prix assez petit que nous pouvons nous permettre de payer pour toutes les valeurs, même les Booléens et les nils qui n'ont pas besoin d'autant d'espace.

Les chaînes de caractères, malheureusement, ne sont pas si petites. Il n'y a pas de longueur maximale pour une chaîne. Même si nous devions artificiellement la plafonner à quelque limite controuvée comme <span name="pascal">255</span> caractères, c'est encore trop de mémoire à dépenser sur chaque valeur unique.

<aside name="pascal">

UCSD Pascal, une des premières implémentations de Pascal, avait cette limite exacte. Au lieu d'utiliser un octet nul de terminaison pour indiquer la fin de la chaîne comme C, les chaînes Pascal commençaient avec une valeur de longueur. Puisque UCSD utilisait seulement un octet unique pour stocker la longueur, les chaînes ne pouvaient pas être plus longues que 255 caractères.

<img src="image/strings/pstring.png" alt="La chaîne Pascal 'hello' avec un octet de longueur de 5 la précédant." />

</aside>

Nous avons besoin d'un moyen de supporter des valeurs dont les tailles varient, parfois grandement. C'est exactement ce pour quoi l'allocation dynamique sur le tas est conçue. Nous pouvons allouer autant d'octets que nous en avons besoin. Nous recevons en retour un pointeur que nous utiliserons pour garder une trace de la valeur alors qu'elle coule à travers la VM.

## Valeurs et Objets

Utiliser le tas pour des valeurs plus grandes, de taille variable et la pile pour celles plus petites, atomiques mène à une représentation à deux niveaux. Chaque valeur Lox que vous pouvez stocker dans une variable ou renvoyer d'une expression sera une Value. Pour les petits types de taille fixe comme les nombres, la charge utile est stockée directement à l'intérieur de la struct Value elle-même.

Si l'objet est plus grand, ses données vivent sur le tas. Alors la charge utile de la Value est un _pointeur_ vers ce blob de mémoire. Nous aurons éventuellement une poignée de types alloués sur le tas dans clox : chaînes, instances, fonctions, vous voyez l'idée. Chaque type a ses propres données uniques, mais il y a aussi un état qu'ils partagent tous que [notre futur ramasse-miettes][gc] utilisera pour gérer leur mémoire.

<img src="image/strings/value.png" class="wide" alt="Disposition des champs des valeurs nombre et obj." />

[gc]: ramasse-miettes.html

Nous appellerons cette représentation commune <span name="short">"Obj"</span>. Chaque valeur Lox dont l'état vit sur le tas est un Obj. Nous pouvons ainsi utiliser un unique nouveau cas `ValueType` pour référer à tous les types alloués sur le tas.

<aside name="short">

"Obj" est court pour "objet", évidemment.

</aside>

^code val-obj (1 before, 1 after)

Quand le type d'une Value est `VAL_OBJ`, la charge utile est un pointeur vers la mémoire du tas, donc nous ajoutons un autre cas à l'union pour ça.

^code union-object (1 before, 1 after)

Comme nous l'avons fait avec les autres types de valeur, nous produisons une couple de macros utiles pour travailler avec les valeurs Obj.

^code is-obj (1 before, 2 after)

Cela évalue à `true` si la Value donnée est un Obj. Si c'est le cas, nous pouvons utiliser ceci :

^code as-obj (2 before, 1 after)

Elle extrait le pointeur Obj de la valeur. Nous pouvons aussi aller dans l'autre sens.

^code obj-val (1 before, 2 after)

Cela prend un pointeur Obj nu et l'enveloppe dans une Value complète.

## Héritage de Structure

Chaque valeur allouée sur le tas est un Obj, mais les <span name="objs">Objs</span> ne sont pas tous les mêmes. Pour les chaînes, nous avons besoin du tableau de caractères. Quand nous arriverons aux instances, elles auront besoin de leurs champs de données. Un objet fonction aura besoin de son morceau de bytecode. Comment gérons-nous différentes charges utiles et tailles ? Nous ne pouvons pas utiliser une autre union comme nous l'avons fait pour Value puisque les tailles sont partout.

<aside name="objs">

Non, je ne sais pas comment prononcer "objs" non plus. J'ai l'impression qu'il devrait y avoir une voyelle là-dedans quelque part.

</aside>

Au lieu de cela, nous utiliserons une autre technique. Elle existe depuis des lustres, au point que la spécification C taille un support spécifique pour elle, mais je ne sais pas si elle a un nom canonique. C'est un exemple de [_type punning_][pun], mais ce terme est trop large. En l'absence de meilleures idées, je l'appellerai **héritage de structure**, parce qu'elle repose sur des structs et suit grossièrement comment l'héritage simple d'état fonctionne dans les langages orientés objet.

[pun]: https://en.wikipedia.org/wiki/Type_punning

Comme une union étiquetée, chaque Obj commence par un champ d'étiquette (tag) qui identifie quel genre d'objet c'est -- chaîne, instance, etc. Suivant cela sont les champs de charge utile. Au lieu d'une union avec des cas pour chaque type, chaque type est sa propre struct séparée. La partie délicate est comment traiter ces structs uniformément puisque C n'a aucun concept d'héritage ou de polymorphisme. J'expliquerai cela bientôt, mais d'abord sortons les trucs préliminaires du chemin.

Le nom "Obj" lui-même réfère à une struct qui contient l'état partagé à travers tous les types d'objet. C'est un peu comme la "classe de base" pour les objets. À cause de certaines dépendances cycliques entre valeurs et objets, nous la déclarons de manière anticipée dans le module "value".

^code forward-declare-obj (2 before, 1 after)

Et la définition réelle est dans un nouveau module.

^code object-h

Pour l'instant, elle contient seulement l'étiquette de type. Sous peu, nous ajouterons d'autres informations de comptabilité pour la gestion de la mémoire. L'enum de type est ceci :

^code obj-type (1 before, 2 after)

Évidemment, cela sera plus utile dans les chapitres ultérieurs après que nous ayons ajouté plus de types alloués sur le tas. Puisque nous accéderons fréquemment à ces types d'étiquette, cela vaut la peine de faire une petite macro qui extrait l'étiquette de type d'objet d'une Value donnée.

^code obj-type-macro (1 before, 2 after)

C'est notre fondation.

Maintenant, construisons les chaînes par-dessus. La charge utile pour les chaînes est définie dans une struct séparée. De nouveau, nous avons besoin de la déclarer de manière anticipée.

^code forward-declare-obj-string (1 before, 2 after)

La définition vit aux côtés d'Obj.

^code obj-string (1 before, 2 after)

Un objet chaîne contient un tableau de caractères. Ceux-ci sont stockés dans un tableau séparé, alloué sur le tas pour que nous mettions de côté seulement autant de place que nécessaire pour chaque chaîne. Nous stockons aussi le nombre d'octets dans le tableau. Ce n'est pas strictement nécessaire mais nous permet de dire combien de mémoire est allouée pour la chaîne sans parcourir le tableau de caractères pour trouver le terminateur nul.

Parce qu'ObjString est un Obj, il a aussi besoin de l'état que tous les Objs partagent. Il accomplit cela en ayant son premier champ être un Obj. C spécifie que les champs de struct sont arrangés en mémoire dans l'ordre où ils sont déclarés. Aussi, quand vous imbriquez des structs, les champs de la struct interne sont étendus juste sur place. Donc la mémoire pour Obj et pour ObjString ressemble à ceci :

<img src="image/strings/obj.png" alt="La disposition mémoire pour les champs dans Obj et ObjString." />

Notez comment les premiers octets d'ObjString s'alignent exactement avec Obj. Ce n'est pas une coïncidence -- C le <span name="spec">mandate</span>. C'est conçu pour permettre un motif intelligent : Vous pouvez prendre un pointeur vers une struct et le convertir en toute sécurité en un pointeur vers son premier champ et inversement.

<aside name="spec">

La partie clé de la spec est :

> &sect; 6.7.2.1 13
>
> À l'intérieur d'un objet structure, les membres non-champs-de-bits et les unités dans lesquelles résident les champs-de-bits ont des adresses qui augmentent dans l'ordre dans lequel ils sont déclarés. Un pointeur vers un objet structure, convenablement converti, pointe vers son membre initial (ou si ce membre est un champ-de-bits, alors vers l'unité dans laquelle il réside), et vice versa. Il peut y avoir du remplissage sans nom à l'intérieur d'un objet structure, mais pas à son début.

</aside>

Étant donné un `ObjString*`, vous pouvez le caster en toute sécurité en `Obj*` et ensuite accéder au champ `type` depuis lui. Chaque ObjString "est" un Obj dans le sens POO de "est". Quand nous ajouterons plus tard d'autres types d'objet, chaque struct aura un Obj comme son premier champ. Tout code qui veut travailler avec tous les objets peut les traiter comme des `Obj*` de base et ignorer tous les autres champs qui peuvent arriver à suivre.

Vous pouvez aller dans l'autre direction aussi. Étant donné un `Obj*`, vous pouvez le "descendre" (downcast) en un `ObjString*`. Bien sûr, vous devez vous assurer que le pointeur `Obj*` que vous avez pointe bien vers le champ `obj` d'un ObjString réel. Sinon, vous réinterprétez de manière non sûre des bits aléatoires de mémoire. Pour détecter qu'un tel cast est sûr, nous ajoutons une autre macro.

^code is-string (1 before, 2 after)

Elle prend une Value, pas un `Obj*` brut parce que la plupart du code dans la VM travaille avec des Values. Elle repose sur cette fonction en ligne :

^code is-obj-type (2 before, 2 after)

Quiz surprise : Pourquoi ne pas juste mettre le corps de cette fonction juste dans la macro ? Qu'est-ce qui est différent à propos de celle-ci comparé aux autres ? Correct, c'est parce que le corps utilise `value` deux fois. Une macro est étendue en insérant l'_expression_ argument chaque endroit où le nom du paramètre apparaît dans le corps. Si une macro utilise un paramètre plus d'une fois, cette expression est évaluée de multiples fois.

C'est mauvais si l'expression a des effets de bord. Si nous mettions le corps de `isObjType()` dans la définition de macro et qu'ensuite vous faisiez, disons,

```c
IS_STRING(POP())
```

alors cela dépilerait deux valeurs de la pile ! Utiliser une fonction corrige cela.

Tant que nous assurons que nous définissons l'étiquette de type correctement chaque fois que nous créons un Obj de quelque type, cette macro nous dira quand il est sûr de caster une valeur vers un type d'objet spécifique. Nous pouvons faire cela en utilisant celles-ci :

^code as-string (1 before, 2 after)

Ces deux macros prennent une Value qui est attendue contenir un pointeur vers un ObjString valide sur le tas. La première renvoie le pointeur `ObjString*`. La seconde fait un pas à travers pour renvoyer le tableau de caractères lui-même, puisque c'est souvent ce dont nous finirons par avoir besoin.

## Chaînes

OK, notre VM peut maintenant représenter des valeurs chaîne. Il est temps d'ajouter les chaînes au langage lui-même. Comme d'habitude, nous commençons dans le front end. Le lexer tokenise déjà les littéraux chaîne, donc c'est au tour du parseur.

^code table-string (1 before, 1 after)

Quand le parseur touche un token chaîne, il appelle cette fonction de parsing :

^code parse-string

Cela prend les caractères de la chaîne <span name="escape">directement</span> du lexème. Les parties `+ 1` et `- 2` enlèvent les guillemets de tête et de traîne. Elle crée ensuite un objet chaîne, l'enveloppe dans une Value, et le bourre dans la table de constantes.

<aside name="escape">

Si Lox supportait les séquences d'échappement de chaîne comme `\n`, nous traduirions celles-ci ici. Puisqu'il ne le fait pas, nous pouvons prendre les caractères tels qu'ils sont.

</aside>

Pour créer la chaîne, nous utilisons `copyString()`, qui est déclarée dans `object.h`.

^code copy-string-h (2 before, 1 after)

Le module compilateur a besoin d'inclure cela.

^code compiler-include-object (2 before, 1 after)

Notre module "object" obtient un fichier d'implémentation où nous définissons la nouvelle fonction.

^code object-c

D'abord, nous allouons un nouveau tableau sur le tas, juste assez grand pour les caractères de la chaîne et le <span name="terminator">terminateur</span> de traîne, en utilisant cette macro de bas niveau qui alloue un tableau avec un type d'élément donné et un compte :

^code allocate (2 before, 1 after)

Une fois que nous avons le tableau, nous copions par-dessus les caractères depuis le lexème et le terminons.

<aside name="terminator" class="bottom">

Nous avons besoin de terminer la chaîne nous-mêmes parce que le lexème pointe à une plage de caractères à l'intérieur de la chaîne source monolithique et n'est pas terminé.

Puisque ObjString stocke la longueur explicitement, nous _pourrions_ laisser le tableau de caractères non terminé, mais coller un terminateur à la fin nous coûte seulement un octet et nous laisse passer le tableau de caractères aux fonctions de bibliothèque standard C qui attendent une chaîne terminée.

</aside>

Vous pourriez vous demander pourquoi l'ObjString ne peut pas juste pointer en retour vers les caractères originaux dans la chaîne source. Certains ObjStrings seront créés dynamiquement à l'exécution comme résultat d'opérations sur les chaînes comme la concaténation. Ces chaînes ont évidemment besoin d'allouer dynamiquement de la mémoire pour les caractères, ce qui signifie que la chaîne a besoin de _libérer_ cette mémoire quand elle n'est plus nécessaire.

Si nous avions un ObjString pour un littéral chaîne, et essayions de libérer son tableau de caractères qui pointait dans la chaîne de code source originale, de mauvaises choses arriveraient. Donc, pour les littéraux, nous copions préventivement les caractères sur le tas. De cette façon, chaque ObjString possède de manière fiable son tableau de caractères et peut le libérer.

Le vrai travail de création d'un objet chaîne se passe dans cette fonction :

^code allocate-string (2 before)

Elle crée un nouvel ObjString sur le tas et ensuite initialise ses champs. C'est un peu comme un constructeur dans un langage POO. En tant que tel, elle appelle d'abord le constructeur de "classe de base" pour initialiser l'état Obj, utilisant une nouvelle macro.

^code allocate-obj (1 before, 2 after)

<span name="factored">Comme</span> la macro précédente, celle-ci existe principalement pour éviter le besoin de caster de manière redondante un `void*` de retour vers le type désiré. La fonctionnalité réelle est ici :

<aside name="factored">

J'admets que ce chapitre a une mer de fonctions aides et de macros à traverser. J'essaie de garder le code joliment factorisé, mais cela mène à un éparpillement de minuscules fonctions. Elles payeront quand nous les réutiliserons plus tard.

</aside>

^code allocate-object (2 before, 2 after)

Elle alloue un objet de la taille donnée sur le tas. Notez que la taille n'est _pas_ juste la taille d'Obj lui-même. L'appelant passe le nombre d'octets pour qu'il y ait de la place pour les champs de charge utile supplémentaires nécessaires par le type d'objet spécifique étant créé.

Ensuite elle initialise l'état Obj -- pour l'instant, c'est juste l'étiquette de type. Cette fonction revient à `allocateString()`, qui finit d'initialiser les champs d'ObjString. <span name="viola">_Voilà_</span>, nous pouvons compiler et exécuter des littéraux chaîne.

<aside name="viola">

<img src="image/strings/viola.png" class="above" alt="Un alto." />

Ne confondez pas "voilà" avec "viola". L'un signifie "ça y est" et l'autre est un instrument à cordes, l'enfant du milieu entre un violon et un violoncelle. Oui, j'ai passé deux heures à dessiner un alto juste pour mentionner ça.

</aside>

## Opérations sur les Chaînes

Nos chaînes fantaisie sont là, mais elles ne font pas grand-chose encore. Une bonne première étape est de faire en sorte que le code d'impression existant ne vomisse pas sur le nouveau type de valeur.

^code call-print-object (1 before, 1 after)

Si la valeur est un objet alloué sur le tas, elle défère à une fonction aide là-bas dans le module "object".

^code print-object-h (1 before, 2 after)

L'implémentation ressemble à ceci :

^code print-object

Nous n'avons qu'un seul type d'objet maintenant, mais cette fonction germera des cas switch additionnels dans les chapitres ultérieurs. Pour les objets chaîne, elle <span name="term-2">imprime</span> simplement le tableau de caractères comme une chaîne C.

<aside name="term-2">

Je vous avais dit que terminer la chaîne deviendrait utile.

</aside>

Les opérateurs d'égalité ont aussi besoin de gérer avec grâce les chaînes. Considérez :

```lox
"string" == "string"
```

Ce sont deux littéraux chaîne séparés. Le compilateur fera deux appels séparés à `copyString()`, créera deux objets ObjString distincts et les stockera comme deux constantes dans le morceau. Ce sont des objets différents dans le tas. Mais nos utilisateurs (et donc nous) s'attendent à ce que les chaînes aient une égalité de valeur. L'expression ci-dessus devrait évaluer à `true`. Cela exige un petit support spécial.

^code strings-equal (1 before, 1 after)

Si les deux valeurs sont toutes deux des chaînes, alors elles sont égales si leurs tableaux de caractères contiennent les mêmes caractères, indépendamment de si elles sont deux objets séparés ou exactement le même. Cela signifie bien que l'égalité de chaîne est plus lente que l'égalité sur les autres types puisqu'elle doit parcourir la chaîne entière. Nous réviserons cela [plus tard][hash], mais cela nous donne la bonne sémantique pour l'instant.

[hash]: tables-de-hachage.html

Finalement, afin d'utiliser `memcmp()` et les nouveaux trucs dans le module "object", nous avons besoin d'une couple d'includes. Ici :

^code value-include-string (1 before, 2 after)

Et ici :

^code value-include-object (2 before, 1 after)

### Concaténation

Les langages adultes fournissent beaucoup d'opérations pour travailler avec les chaînes -- accès aux caractères individuels, la longueur de la chaîne, changer la casse, diviser, joindre, chercher, etc. Quand vous implémentez votre langage, vous voudrez probablement tout ça. Mais pour ce livre, nous gardons les choses _très_ minimales.

La seule opération intéressante que nous supportons sur les chaînes est `+`. Si vous utilisez cet opérateur sur deux objets chaîne, il produit une nouvelle chaîne qui est une concaténation des deux opérandes. Puisque Lox est dynamiquement typé, nous ne pouvons pas dire quel comportement est nécessaire à la compilation parce que nous ne connaissons pas les types des opérandes avant l'exécution. Ainsi, l'instruction `OP_ADD` inspecte dynamiquement les opérandes et choisit la bonne opération.

^code add-strings (1 before, 1 after)

Si les deux opérandes sont des chaînes, il concatène. S'ils sont tous deux des nombres, il les additionne. Toute autre <span name="convert">combinaison</span> de types d'opérande est une erreur d'exécution.

<aside name="convert" class="bottom">

C'est plus conservateur que la plupart des langages. Dans d'autres langages, si un opérande est une chaîne, l'autre peut être n'importe quel type et il sera implicitement converti en une chaîne avant de concaténer les deux.

Je pense que c'est une fonctionnalité correcte, mais exigerait d'écrire du code fastidieux "convertir en chaîne" pour chaque type, donc je l'ai laissée hors de Lox.

</aside>

Pour concaténer des chaînes, nous définissons une nouvelle fonction.

^code concatenate

Elle est assez verbeuse, comme le code C qui travaille avec les chaînes tend à être. D'abord, nous calculons la longueur de la chaîne résultat basée sur les longueurs des opérandes. Nous allouons un tableau de caractères pour le résultat et ensuite copions les deux moitiés dedans. Comme toujours, nous assurons soigneusement que la chaîne est terminée.

Afin d'appeler `memcpy()`, la VM a besoin d'un include.

^code vm-include-string (1 before, 2 after)

Finalement, nous produisons un ObjString pour contenir ces caractères. Cette fois nous utilisons une nouvelle fonction, `takeString()`.

^code take-string-h (2 before, 1 after)

L'implémentation ressemble à ceci :

^code take-string

La fonction `copyString()` précédente suppose qu'elle ne _peut pas_ prendre la propriété des caractères que vous passez dedans. Au lieu de cela, elle crée de manière conservatrice une copie des caractères sur le tas que l'ObjString peut posséder. C'est la bonne chose pour les littéraux chaîne où les caractères passés sont au milieu de la chaîne source.

Mais, pour la concaténation, nous avons déjà alloué dynamiquement un tableau de caractères sur le tas. Faire une autre copie de cela serait redondant (et signifierait que `concatenate()` doit se souvenir de libérer sa copie). Au lieu de cela, cette fonction réclame la propriété de la chaîne que vous lui donnez.

Comme d'habitude, coudre cette fonctionnalité ensemble exige une couple d'includes.

^code vm-include-object-memory (1 before, 1 after)

## Libérer les Objets

Contemplez cette expression à l'apparence inoffensive :

```lox
"st" + "ri" + "ng"
```

Quand le compilateur mâche à travers ceci, il alloue un ObjString pour chacun de ces trois littéraux chaîne et les stocke dans la table de constantes du morceau et génère ce <span name="stack">bytecode</span> :

<aside name="stack">

Voici à quoi ressemble la pile après chaque instruction :

<img src="image/strings/stack.png" alt="L'état de la pile à chaque instruction." />

</aside>

```text
0000    OP_CONSTANT         0 "st"
0002    OP_CONSTANT         1 "ri"
0004    OP_ADD
0005    OP_CONSTANT         2 "ng"
0007    OP_ADD
0008    OP_RETURN
```

Les deux premières instructions poussent `"st"` et `"ri"` sur la pile. Ensuite l'`OP_ADD` dépile ceux-ci et les concatène. Cela alloue dynamiquement une nouvelle chaîne `"stri"` sur le tas. La VM pousse cela et ensuite pousse la constante `"ng"`. Le dernier `OP_ADD` dépile `"stri"` et `"ng"`, les concatène, et pousse le résultat : `"string"`. Super, c'est ce que nous attendons.

Mais, attendez. Qu'est-ce qui est arrivé à cette chaîne `"stri"` ? Nous l'avons allouée dynamiquement, ensuite la VM l'a jetée après l'avoir concaténée avec `"ng"`. Nous l'avons dépilée de la pile et n'avons plus de référence vers elle, mais nous n'avons jamais libéré sa mémoire. Nous avons nous-mêmes une fuite de mémoire classique.

Bien sûr, il est parfaitement correct pour le _programme Lox_ d'oublier les chaînes intermédiaires et de ne pas s'inquiéter de les libérer. Lox gère automatiquement la mémoire pour le compte de l'utilisateur. La responsabilité de gérer la mémoire ne _disparaît_ pas. Au lieu de cela, elle tombe sur nos épaules en tant qu'implémenteurs de VM.

La <span name="borrowed">solution</span> complète est un [ramasse-miettes][gc] qui récupère la mémoire inutilisée pendant que le programme tourne. Nous avons d'autres trucs à mettre en place avant que nous soyons prêts à tacler ce projet. Jusque-là, nous vivons sur du temps emprunté. Plus nous attendons pour ajouter le collecteur, plus il est dur à faire.

<aside name="borrowed">

J'ai vu un certain nombre de gens implémenter de larges pans de leur langage avant d'essayer de commencer sur le GC. Pour le genre de programmes jouets que vous lancez typiquement pendant qu'un langage est développé, vous ne tombez en fait pas à court de mémoire avant d'atteindre la fin du programme, donc cela vous mène étonnamment loin.

Mais cela sous-estime combien il est _dur_ d'ajouter un ramasse-miettes plus tard. Le collecteur _doit_ assurer qu'il peut trouver chaque bout de mémoire qui _est_ encore utilisé de sorte qu'il ne collecte pas des données vivantes. Il y a des centaines d'endroits où une implémentation de langage peut écureuiller une référence vers quelque objet. Si vous ne les trouvez pas tous, vous obtenez des bugs cauchemardesques.

J'ai vu des implémentations de langage mourir parce qu'il était trop dur de mettre le GC dedans plus tard. Si votre langage a besoin d'un GC, faites-le marcher aussi tôt que vous pouvez. C'est une préoccupation transverse qui touche la base de code entière.

</aside>

Aujourd'hui, nous devrions au moins faire le strict minimum : éviter de _fuiter_ de la mémoire en nous assurant que la VM peut toujours trouver chaque objet alloué même si le programme Lox lui-même ne les référence plus. Il y a beaucoup de techniques sophistiquées que les gestionnaires de mémoire avancés utilisent pour allouer et suivre la mémoire pour les objets. Nous allons prendre l'approche pratique la plus simple.

Nous créerons une liste chaînée qui stocke chaque Obj. La VM peut traverser cette liste pour trouver chaque objet unique qui a été alloué sur le tas, que le programme de l'utilisateur ou la pile de la VM ait encore une référence vers lui ou non.

Nous pourrions définir une struct de nœud de liste chaînée séparée mais alors nous aurions à allouer ceux-là aussi. Au lieu de cela, nous utiliserons une **liste intrusive** -- la struct Obj elle-même sera le nœud de liste chaînée. Chaque Obj obtient un pointeur vers le prochain Obj dans la chaîne.

^code next-field (2 before, 1 after)

La VM stocke un pointeur vers la tête de la liste.

^code objects-root (1 before, 1 after)

Quand nous initialisons la VM pour la première fois, il n'y a pas d'objets alloués.

^code init-objects-root (1 before, 1 after)

Chaque fois que nous allouons un Obj, nous l'insérons dans la liste.

^code add-to-list (1 before, 1 after)

Puisque c'est une liste chaînée simple, l'endroit le plus facile pour l'insérer est comme la tête. De cette façon, nous n'avons pas besoin de stocker aussi un pointeur vers la queue et de le garder à jour.

Le module "object" utilise directement la variable globale `vm` du module "vm", donc nous avons besoin d'exposer ça extérieurement.

^code extern-vm (2 before, 1 after)

Éventuellement, le ramasse-miettes libérera la mémoire alors que la VM tourne encore. Mais, même alors, il y aura habituellement des objets inutilisés traînant encore en mémoire quand le programme de l'utilisateur termine. La VM devrait libérer ceux-là aussi.

Il n'y a pas de logique sophistiquée pour cela. Une fois que le programme est fini, nous pouvons libérer _chaque_ objet. Nous pouvons et devrions implémenter cela maintenant.

^code call-free-objects (1 before, 1 after)

Cette fonction vide que nous avons définie [il y a longtemps][vm] fait finalement quelque chose ! Elle appelle ceci :

[vm]: machine-virtuelle.html#une-machine-d-exécution-d-instruction

^code free-objects-h (1 before, 2 after)

Voici comment nous libérons les objets :

^code free-objects

C'est une implémentation de manuel de CS 101 de parcourir une liste chaînée et de libérer ses nœuds. Pour chaque nœud, nous appelons :

^code free-object

Nous ne libérons pas seulement l'Obj lui-même. Puisque certains types d'objet allouent aussi d'autre mémoire qu'ils possèdent, nous avons aussi besoin d'un peu de code spécifique au type pour gérer les besoins spéciaux de chaque type d'objet. Ici, cela signifie que nous libérons le tableau de caractères et ensuite libérons l'ObjString. Ceux-ci utilisent tous deux une dernière macro de gestion de la mémoire.

^code free (1 before, 2 after)

C'est un minuscule <span name="free">emballage</span> autour de `reallocate()` qui "redimensionne" une allocation à zéro octet.

<aside name="free">

Utiliser `reallocate()` pour libérer de la mémoire pourrait sembler inutile. Pourquoi ne pas juste appeler `free()` ? Plus tard, cela aidera la VM à suivre combien de mémoire est encore utilisée. Si toute allocation et libération passe par `reallocate()`, il est facile de garder un compte courant du nombre d'octets de mémoire allouée.

</aside>

Comme d'habitude, nous avons besoin d'un include pour câbler tout ensemble.

^code memory-include-object (1 before, 2 after)

Ensuite dans le fichier d'implémentation :

^code memory-include-vm (1 before, 2 after)

Avec ceci, notre VM ne fuite plus de mémoire. Comme un bon programme C, elle nettoie son désordre avant de quitter. Mais elle ne libère aucuns objets pendant que la VM tourne. Plus tard, quand il sera possible d'écrire des programmes Lox plus longs, la VM mangera de plus en plus de mémoire alors qu'elle va, ne relâchant pas un seul octet jusqu'à ce que le programme entier soit fini.

Nous n'adresserons pas cela jusqu'à ce que nous ayons ajouté [un vrai ramasse-miettes][gc], mais c'est une grande étape. Nous avons maintenant l'infrastructure pour supporter une variété de différentes sortes d'objets alloués dynamiquement. Et nous avons utilisé cela pour ajouter les chaînes à clox, l'un des types les plus utilisés dans la plupart des langages de programmation. Les chaînes à leur tour nous permettent de construire un autre type de données fondamental, spécialement dans les langages dynamiques : la vénérable [table de hachage][]. Mais c'est pour le prochain chapitre...

[table de hachage]: tables-de-hachage.html

<div class="challenges">

## Défis

1.  Chaque chaîne exige deux allocations dynamiques séparées -- une pour l'ObjString et une seconde pour le tableau de caractères. Accéder aux caractères depuis une valeur exige deux indirections de pointeur, ce qui peut être mauvais pour la performance. Une solution plus efficace repose sur une technique appelée **[membres de tableau flexibles][flexible array members]**. Utilisez cela pour stocker l'ObjString et son tableau de caractères dans une allocation contiguë unique.

2.  Quand nous créons l'ObjString pour chaque littéral chaîne, nous copions les caractères sur le tas. De cette façon, quand la chaîne est plus tard libérée, nous savons qu'il est sûr de libérer les caractères aussi.

    C'est une approche plus simple mais gaspille un peu de mémoire, ce qui pourrait être un problème sur des appareils très contraints. Au lieu de cela, nous pourrions garder une trace de quels ObjStrings possèdent leur tableau de caractères et lesquels sont des "chaînes constantes" qui pointent juste en retour vers la chaîne source originale ou quelque autre emplacement non libérable. Ajoutez le support pour cela.

3.  Si Lox était votre langage, que lui feriez-vous faire quand un utilisateur essaie d'utiliser `+` avec un opérande chaîne et l'autre d'un autre type ? Justifiez votre choix. Que font d'autres langages ?

[flexible array members]: https://en.wikipedia.org/wiki/Flexible_array_member

</div>

<div class="design-note">

## Note de Conception : Encodage de Chaîne

Dans ce livre, j'essaie de ne pas fuir les problèmes gnagnus que vous rencontrerez dans une vraie implémentation de langage. Nous pourrions ne pas toujours utiliser la solution la plus _sophistiquée_ -- c'est un livre d'intro après tout -- mais je ne pense pas qu'il soit honnête de prétendre que le problème n'existe pas du tout. Cependant, j'ai contourné une énigme vraiment méchante : décider comment représenter les chaînes.

Il y a deux facettes à un encodage de chaîne :

- **Qu'est-ce qu'un "caractère" unique dans une chaîne ?** Combien de valeurs différentes y a-t-il et que représentent-elles ? La première réponse standard largement adoptée à cela était [ASCII][]. Il vous donnait 127 valeurs de caractères différentes et spécifiait ce qu'elles étaient. C'était génial... si vous ne vous souciez que de l'anglais. Bien qu'il ait des caractères bizarres, la plupart oubliés comme "séparateur d'enregistrement" et "attente synchrone", il n'a pas un seul trema, aigu, ou grave. Il ne peut pas représenter "jalapeño", "naïve", <span name="gruyere">"Gruyère"</span>, ou "Mötley Crüe".

      <aside name="gruyere">

    Il va sans dire qu'un langage qui ne laisse pas discuter de Gruyère ou de Mötley Crüe est un langage qui ne vaut pas la peine d'être utilisé.

      </aside>

    Ensuite vint [Unicode][]. Initialement, il supportait 16 384 caractères différents (**points de code**), qui tenaient joliment dans 16 bits avec une couple de bits à épargner. Plus tard cela a grandi et grandi, et maintenant il y a bien plus de 100 000 points de code différents incluant de tels instruments vitaux de communication humaine comme 💩 (Caractère Unicode 'TAS DE CACA', `U+1F4A9`).

    Même cette longue liste de points de code n'est pas suffisante pour représenter chaque glyphe visible possible qu'un langage pourrait supporter. Pour gérer cela, Unicode a aussi des **caractères combinants** qui modifient un point de code précédent. Par exemple, "a" suivi par le caractère combinant "¨" vous donne "ä". (Pour rendre les choses plus confuses Unicode a _aussi_ un point de code unique qui ressemble à "ä".)

    Si un utilisateur accède au quatrième "caractère" dans "naïve", s'attend-il à récupérer "v" ou &ldquo;¨&rdquo; ? Le premier signifie qu'ils pensent à chaque point de code et son caractère combinant comme une unité unique -- ce que Unicode appelle un **amas de graphèmes étendu** -- le dernier signifie qu'ils pensent en points de code individuels. Auquel vos utilisateurs s'attendent-ils ?

- **Comment une unité unique est-elle représentée en mémoire ?** La plupart des systèmes utilisant ASCII donnaient un octet unique à chaque caractère et laissaient le bit haut inutilisé. Unicode a une poignée d'encodages communs. UTF-16 empaquette la plupart des points de code dans 16 bits. C'était génial quand chaque point de code tenait dans cette taille. Quand cela a débordé, ils ont ajouté des _paires de substitution_ qui utilisent de multiples unités de code de 16 bits pour représenter un point de code unique. UTF-32 est la prochaine évolution de UTF-16 -- il donne un plein 32 bits à chaque point de code.

    UTF-8 est plus complexe que l'un ou l'autre de ceux-ci. Il utilise un nombre variable d'octets pour encoder un point de code. Les points de code de valeur plus basse tiennent dans moins d'octets. Puisque chaque caractère peut occuper un nombre différent d'octets, vous ne pouvez pas directement indexer dans la chaîne pour trouver un point de code spécifique. Si vous voulez, disons, le 10ème point de code, vous ne savez pas à combien d'octets dans la chaîne c'est sans marcher et décoder tous les précédents.

[ascii]: https://en.wikipedia.org/wiki/ASCII
[unicode]: https://en.wikipedia.org/wiki/Unicode

Choisir une représentation de caractère et un encodage implique des compromis fondamentaux. Comme beaucoup de choses en ingénierie, il n'y a pas de solution <span name="python">parfaite</span> :

<aside name="python">

Un exemple de combien ce problème est difficile vient de Python. La transition douloureusement longue de Python 2 à 3 est pénible surtout à cause de ses changements autour de l'encodage de chaîne.

</aside>

- ASCII est efficace en mémoire et rapide, mais il jette les langages non-latins sur le côté.

- UTF-32 est rapide et supporte toute la plage Unicode, mais gaspille beaucoup de mémoire étant donné que la plupart des points de code tendent à être dans la plage basse de valeurs, où un plein 32 bits n'est pas nécessaire.

- UTF-8 est efficace en mémoire et supporte toute la plage Unicode, mais son encodage à longueur variable le rend lent pour accéder à des points de code arbitraires.

- UTF-16 est pire que tous ceux-là -- une conséquence laide d'Unicode dépassant sa plage 16-bit antérieure. Il est moins efficace en mémoire que UTF-8 mais est toujours un encodage à longueur variable grâce aux paires de substitution. Évitez-le si vous pouvez. Hélas, si votre langage a besoin de tourner sur ou d'interopérer avec le navigateur, la JVM, ou le CLR, vous pourriez être coincé avec, puisque ceux-ci utilisent tous UTF-16 pour leurs chaînes et vous ne voulez pas avoir à convertir chaque fois que vous passez une chaîne au système sous-jacent.

Une option est de prendre l'approche maximale et de faire la chose la "plus juste". Supporter tous les points de code Unicode. En interne, sélectionner un encodage pour chaque chaîne basé sur son contenu -- utiliser ASCII si chaque point de code tient dans un octet, UTF-16 s'il n'y a pas de paires de substitution, etc. Fournir des APIs pour laisser les utilisateurs itérer sur à la fois les points de code et les amas de graphèmes étendus.

Cela couvre toutes vos bases mais est vraiment complexe. C'est beaucoup à implémenter, déboguer, et optimiser. Quand on sérialise des chaînes ou qu'on interopère avec d'autres systèmes, vous avez à gérer tous les encodages. Les utilisateurs ont besoin de comprendre les deux APIs d'indexation et savoir laquelle utiliser quand. C'est l'approche que les langages plus récents, gros tendent à prendre -- comme Raku et Swift.

Un compromis plus simple est de toujours encoder en utilisant UTF-8 et seulement exposer une API qui travaille avec les points de code. Pour les utilisateurs qui veulent travailler avec les amas de graphèmes, laissez-les utiliser une bibliothèque tierce pour cela. C'est moins Latin-centrique qu'ASCII mais pas beaucoup plus complexe. Vous perdez l'indexation directe rapide par point de code, mais vous pouvez habituellement vivre sans cela ou vous permettre de le rendre _O(n)_ au lieu de _O(1)_.

Si je concevais un gros langage de trait pour des gens écrivant de larges applications, j'irais probablement avec l'approche maximale. Pour mon petit langage de script embarqué [Wren][], je suis allé avec UTF-8 et les points de code.

[wren]: http://wren.io

</div>
