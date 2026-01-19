> Et comme l'imagination donne corps<br />
> Aux formes de choses inconnues, la plume du poète<br />
> Les transforme en figures et donne à ce rien aérien<br />
> Une habitation locale et un nom.
>
> <cite>William Shakespeare, <em>Le Songe d'une nuit d'été</em></cite>

Le [chapitre précédent][last chapter] a introduit les variables dans clox, mais seulement de la variété <span name="global">globale</span>. Dans ce chapitre, nous étendrons cela pour supporter les blocs, la portée de bloc, et les variables locales. Dans jlox, nous avons réussi à empaqueter tout ça et les globales dans un seul chapitre. Pour clox, c'est deux chapitres de travail partiellement parce que, franchement, tout prend plus d'efforts en C.

<aside name="global">

Il y a probablement une blague bête "penser globalement, agir localement" ici, mais je lutte pour la trouver.

</aside>

[last chapter]: variables-globales.html

Mais une raison encore plus importante est que notre approche des variables locales sera tout à fait différente de comment nous avons implémenté les globales. Les variables globales sont liées tardivement dans Lox. "Tard" dans ce contexte signifie "résolues après le moment de la compilation". C'est bon pour garder le compilateur simple, mais pas génial pour la performance. Les variables locales sont une des <span name="params">parties</span> les plus utilisées d'un langage. Si les locales sont lentes, _tout_ est lent. Donc nous voulons une stratégie pour les variables locales qui soit aussi efficace que possible.

<aside name="params">

Les paramètres de fonction sont aussi lourdement utilisés. Ils fonctionnent comme des variables locales aussi, donc nous utiliserons la même technique d'implémentation pour eux.

</aside>

Heureusement, la portée lexicale est là pour nous aider. Comme le nom l'implique, la portée lexicale signifie que nous pouvons résoudre une variable locale juste en regardant le texte du programme -- les locales ne sont _pas_ liées tardivement. Tout travail de traitement que nous faisons dans le compilateur est du travail que nous _n'avons pas_ à faire à l'exécution, donc notre implémentation de variables locales s'appuiera lourdement sur le compilateur.

## Représenter les Variables Locales

La chose sympa à propos de bidouiller sur un langage de programmation dans les temps modernes est qu'il y a une longue lignée d'autres langages desquels apprendre. Alors comment C et Java gèrent-ils leurs variables locales ? Eh bien, sur la pile, bien sûr ! Ils utilisent typiquement les mécanismes de pile natifs supportés par la puce et l'OS. C'est un peu trop bas niveau pour nous, mais à l'intérieur du monde virtuel de clox, nous avons notre propre pile que nous pouvons utiliser.

Juste maintenant, nous l'utilisons seulement pour tenir des **temporaires** -- des blobs de données à courte vie dont nous avons besoin de nous souvenir pendant le calcul d'une expression. Tant que nous ne nous mettons pas en travers de ceux-là, nous pouvons fourrer nos variables locales sur la pile aussi. C'est génial pour la performance. Allouer de l'espace pour une nouvelle locale exige seulement d'incrémenter le pointeur `stackTop`, et libérer est de même un décrément. Accéder à une variable depuis un emplacement de pile connu est une recherche indexée de tableau.

Nous devons faire attention, cependant. La VM attend que la pile se comporte comme, eh bien, une pile. Nous devons être OK avec l'allocation de nouvelles locales seulement au sommet de la pile, et nous devons accepter que nous pouvons jeter une locale seulement quand rien n'est au-dessus d'elle sur la pile. Aussi, nous devons nous assurer que les temporaires n'interfèrent pas.

Commode, la conception de Lox est en <span name="harmony">harmonie</span> avec ces contraintes. Les nouvelles locales sont toujours créées par des instructions de déclaration. Les instructions ne se nichent pas à l'intérieur d'expressions, donc il n'y a jamais de temporaires sur la pile quand une instruction commence à s'exécuter. Les blocs sont strictement imbriqués. Quand un bloc finit, il emmène toujours avec lui les locales déclarées le plus récemment, les plus intérieures. Puisque celles-ci sont aussi les locales qui sont entrées dans la portée en dernier, elles devraient être au sommet de la pile là où nous avons besoin d'elles.

<aside name="harmony">

Cet alignement n'est évidemment pas une coïncidence. J'ai conçu Lox pour être susceptible à la compilation à une passe vers un bytecode basé sur la pile. Mais je n'ai pas eu à régler le langage trop pour qu'il tienne dans ces restrictions. La plupart de sa conception devrait sembler assez naturelle.

C'est en grande partie parce que l'histoire des langages est profondément liée à la compilation à une passe et -- à un degré moindre -- aux architectures basées sur la pile. La portée de bloc de Lox suit une tradition s'étendant jusqu'à BCPL. En tant que programmeurs, notre intuition de ce qui est "normal" dans un langage est informée même aujourd'hui par les limitations matérielles d'antan.

</aside>

Marchez à travers cet exemple de programme et regardez comment les variables locales entrent et sortent de la portée :

<img src="image/local-variables/scopes.png" alt="Une série de variables locales entrent et sortent de la portée d'une manière semblable à une pile." />

Voyez comment elles s'ajustent à une pile parfaitement ? Il semble que la pile fonctionnera pour stocker les locales à l'exécution. Mais nous pouvons aller plus loin que ça. Non seulement savons-nous _qu_'elles seront sur la pile, mais nous pouvons même épingler précisément _où_ elles seront sur la pile. Puisque le compilateur sait exactement quelles variables locales sont dans la portée à n'importe quel point dans le temps, il peut effectivement simuler la pile pendant la compilation et noter <span name="fn">où</span> dans la pile chaque variable vit.

Nous tirerons avantage de cela en utilisant ces décalages de pile comme opérandes pour les instructions bytecode qui lisent et stockent les variables locales. Cela rend le travail avec les locales délicieusement rapide -- aussi simple qu'indexer dans un tableau.

<aside name="fn">

Dans ce chapitre, les locales commencent au bas du tableau de pile de la VM et sont indexées depuis là. Quand nous ajouterons les [fonctions][], ce schéma deviendra un peu plus complexe. Chaque fonction a besoin de sa propre région de la pile pour ses paramètres et variables locales. Mais, comme nous le verrons, cela n'ajoute pas autant de complexité que vous pourriez vous y attendre.

[functions]: appels-et-fonctions.html

</aside>

Il y a beaucoup d'état que nous avons besoin de suivre dans le compilateur pour faire marcher toute cette chose, donc commençons là. Dans jlox, nous avons utilisé une chaîne liée de HashMaps d'"environnement" pour suivre quelles variables locales étaient actuellement dans la portée. C'est en quelque sorte la façon classique, scolaire de représenter la portée lexicale. Pour clox, comme d'habitude, nous allons un peu plus près du métal. Tout l'état vit dans une nouvelle struct.

^code compiler-struct (1 before, 2 after)

Nous avons un tableau simple, plat de toutes les locales qui sont dans la portée pendant chaque point dans le processus de compilation. Elles sont <span name="order">ordonnées</span> dans le tableau dans l'ordre où leurs déclarations apparaissent dans le code. Puisque l'opérande d'instruction que nous utiliserons pour encoder une locale est un octet unique, notre VM a une limite dure sur le nombre de locales qui peuvent être dans la portée à la fois. Cela signifie que nous pouvons aussi donner au tableau de locales une taille fixe.

<aside name="order">

Nous écrivons un compilateur à une passe, donc ce n'est pas comme si nous avions _trop_ d'autres options pour comment les ordonner dans le tableau.

</aside>

^code uint8-count (1 before, 2 after)

De retour dans la struct Compiler, le champ `localCount` suit combien de locales sont dans la portée -- combien de ces emplacements de tableau sont utilisés. Nous suivons aussi la "profondeur de portée". C'est le nombre de blocs entourant le petit bout de code actuel que nous compilons.

Notre interpréteur Java utilisait une chaîne de maps pour garder les variables de chaque bloc séparées de celles des autres blocs. Cette fois, nous numéroterons simplement les variables avec le niveau d'imbrication où elles apparaissent. Zéro est la portée globale, un est le premier bloc de niveau supérieur, deux est à l'intérieur de ça, vous voyez l'idée. Nous utilisons ceci pour suivre à quel bloc chaque locale appartient afin que nous sachions quelles locales jeter quand un bloc finit.

Chaque locale dans le tableau est une de celles-ci :

^code local-struct (1 before, 2 after)

Nous stockons le nom de la variable. Quand nous résolvons un identifiant, nous comparons le léxème de l'identifiant avec le nom de chaque locale pour trouver une correspondance. Il est assez dur de résoudre une variable si vous ne connaissez pas son nom. Le champ `depth` enregistre la profondeur de portée du bloc où la variable locale a été déclarée. C'est tout l'état dont nous avons besoin pour l'instant.

C'est une représentation très différente de ce que nous avions dans jlox, mais elle nous laisse toujours répondre à toutes les mêmes questions que notre compilateur a besoin de poser à l'environnement lexical. L'étape suivante est de comprendre comment le compilateur _obtient_ cet état. Si nous étions des ingénieurs avec des <span name="thread">principes</span>, nous donnerions à chaque fonction dans le front end un paramètre qui accepte un pointeur vers un Compiler. Nous créerions un Compiler au début et l'enfilerions soigneusement à travers chaque appel de fonction... mais cela signifierait beaucoup de changements ennuyeux au code que nous avons déjà écrit, donc voici une variable globale au lieu de cela :

<aside name="thread">

En particulier, si nous voulons jamais utiliser notre compilateur dans une application multi-threadée, possiblement avec de multiples compilateurs tournant en parallèle, alors utiliser une variable globale est une _mauvaise_ idée.

</aside>

^code current-compiler (1 before, 1 after)

Voici une petite fonction pour initialiser le compilateur :

^code init-compiler

Quand nous démarrons d'abord la VM, nous l'appelons pour tout mettre dans un état propre.

^code compiler (1 before, 1 after)

Notre compilateur a les données dont il a besoin, mais pas les opérations sur ces données. Il n'y a pas de moyen de créer et détruire des portées, ou ajouter et résoudre des variables. Nous ajouterons celles-ci au fur et à mesure que nous en aurons besoin. D'abord, commençons à construire quelques fonctionnalités de langage.

## Instructions de Bloc

Avant que nous puissions avoir des variables locales, nous avons besoin de quelques portées locales. Celles-ci viennent de deux choses : les corps de fonction et les <span name="block">blocs</span>. Les fonctions sont un gros morceau de travail auquel nous nous attaquerons dans [un chapitre ultérieur][functions], donc pour l'instant nous allons seulement faire les blocs. Comme d'habitude, nous commençons avec la syntaxe. La nouvelle grammaire que nous introduirons est :

```ebnf
statement      → exprStmt
               | printStmt
               | block ;

block          → "{" declaration* "}" ;
```

<aside name="block">

Quand vous y pensez, "bloc" est un nom bizarre. Utilisé métaphoriquement, "bloc" signifie habituellement une petite unité indivisible, mais pour une raison quelconque, le comité Algol 60 a décidé de l'utiliser pour faire référence à une structure _composée_ -- une série d'instructions. Cela pourrait être pire, je suppose. Algol 58 appelait `begin` et `end` des "parenthèses d'instruction".

<img src="image/local-variables/block.png" alt="Un parpaing (cinder block)." class="above" />

</aside>

Les blocs sont une sorte d'instruction, donc la règle pour eux va dans la production `statement`. Le code correspondant pour en compiler un ressemble à ceci :

^code parse-block (2 before, 1 after)

Après avoir <span name="helper">analysé</span> l'accolade initiale, nous utilisons cette fonction aide pour compiler le reste du bloc :

<aside name="helper">

Cette fonction deviendra pratique plus tard pour compiler les corps de fonction.

</aside>

^code block

Elle continue d'analyser les déclarations et les instructions jusqu'à ce qu'elle touche l'accolade fermante. Comme nous le faisons avec n'importe quelle boucle dans l'analyseur, nous vérifions aussi la fin du flux de jetons. De cette façon, s'il y a un programme malformé avec une accolade fermante manquante, le compilateur ne reste pas coincé dans une boucle.

Exécuter un bloc signifie simplement exécuter les instructions qu'il contient, l'une après l'autre, donc il n'y a pas grand-chose à leur compilation. La chose sémantiquement intéressante que les blocs font est de créer des portées. Avant que nous compilions le corps d'un bloc, nous appelons cette fonction pour entrer dans une nouvelle portée locale :

^code begin-scope

Afin de "créer" une portée, tout ce que nous faisons est d'incrémenter la profondeur courante. C'est certainement beaucoup plus rapide que jlox, qui allouait une HashMap entièrement nouvelle pour chacune. Étant donné `beginScope()`, vous pouvez probablement deviner ce que `endScope()` fait.

^code end-scope

C'est ça pour les blocs et les portées -- plus ou moins -- donc nous sommes prêts à fourrer quelques variables dedans.

## Déclarer des Variables Locales

Habituellement nous commençons avec l'analyse ici, mais notre compilateur supporte déjà l'analyse et la compilation des déclarations de variable. Nous avons des instructions `var`, des expressions identifiants et l'affectation là-dedans maintenant. C'est juste que le compilateur suppose que toutes les variables sont globales. Donc nous n'avons besoin d'aucun nouveau support d'analyse, nous avons juste besoin d'accrocher la nouvelle sémantique de portée au code existant.

<img src="image/local-variables/declaration.png" alt="Le flux de code à l'intérieur de varDeclaration()." />

L'analyse de déclaration de variable commence dans `varDeclaration()` et repose sur une couple d'autres fonctions. D'abord, `parseVariable()` consomme le jeton identifiant pour le nom de variable, ajoute son léxème à la table des constantes du fragment comme une chaîne, et renvoie ensuite l'index de table constante où il a été ajouté. Ensuite, après que `varDeclaration()` compile l'initialisateur, elle appelle `defineVariable()` pour émettre le bytecode pour stocker la valeur de la variable dans la table de hachage des variables globales.

Ces deux aides ont besoin de quelques changements pour supporter les variables locales. Dans `parseVariable()`, nous ajoutons :

^code parse-local (1 before, 1 after)

D'abord, nous "déclarons" la variable. J'arriverai à ce que ça signifie dans une seconde. Après cela, nous sortons de la fonction si nous sommes dans une portée locale. À l'exécution, les locales ne sont pas cherchées par nom. Il n'y a pas besoin de fourrer le nom de la variable dans la table des constantes, donc si la déclaration est à l'intérieur d'une portée locale, nous renvoyons un index de table factice au lieu de cela.

Là-bas dans `defineVariable()`, nous avons besoin d'émettre le code pour stocker une variable locale si nous sommes dans une portée locale. Cela ressemble à ceci :

^code define-variable (1 before, 1 after)

Attends, quoi ? Ouaip. C'est tout. Il n'y a pas de code pour créer une variable locale à l'exécution. Pensez à dans quel état est la VM. Elle a déjà exécuté le code pour l'initialisateur de la variable (ou le `nil` implicite si l'utilisateur a omis un initialisateur), et cette valeur est assise juste au sommet de la pile comme le seul temporaire restant. Nous savons aussi que les nouvelles locales sont allouées au sommet de la pile... juste là où cette valeur est déjà. Ainsi, il n'y a rien à faire. Le temporaire _devient_ simplement la variable locale. Ça ne devient pas beaucoup plus efficace que ça.

<span name="locals"></span>

<img src="image/local-variables/local-slots.png" alt="Marchant à travers l'exécution bytecode montrant que chaque résultat d'initialisateur finit dans l'emplacement de la locale." />

<aside name="locals">

Le code sur la gauche compile vers la séquence d'instructions sur la droite.

</aside>

OK, donc de quoi s'agit-il avec "déclarer" ? Voici ce que cela fait :

^code declare-variable

C'est le point où le compilateur enregistre l'existence de la variable. Nous faisons cela seulement pour les locales, donc si nous sommes dans la portée globale de niveau supérieur, nous abandonnons juste. Parce que les variables globales sont liées tardivement, le compilateur ne garde pas trace de quelles déclarations pour elles il a vues.

Mais pour les variables locales, le compilateur a bien besoin de se souvenir que la variable existe. C'est ce que la déclarer fait -- cela l'ajoute à la liste de variables du compilateur dans la portée courante. Nous implémentons cela en utilisant une autre nouvelle fonction.

^code add-local

Ceci initialise la prochaine Local disponible dans le tableau de variables du compilateur. Cela stocke le <span name="lexeme">nom</span> de la variable et la profondeur de la portée qui possède la variable.

<aside name="lexeme">

Inquiet à propos de la durée de vie de la chaîne pour le nom de la variable ? La Local stocke directement une copie de la struct Token pour l'identifiant. Les Tokens stockent un pointeur vers le premier caractère de leur léxème et la longueur du léxème. Ce pointeur pointe dans la chaîne source originale pour le script ou l'entrée REPL étant compilés.

Tant que cette chaîne reste autour pendant le processus de compilation entier -- ce qu'elle doit puisque, vous savez, nous la compilons -- alors tous les jetons pointant dedans sont bons.

</aside>

Notre implémentation est bien pour un programme Lox correct, mais quoi à propos du code invalide ? Visons à être robustes. La première erreur à gérer n'est pas vraiment la faute de l'utilisateur, mais plus une limitation de la VM. Les instructions pour travailler avec les variables locales font référence à elles par index d'emplacement. Cet index est stocké dans un opérande d'un octet unique, ce qui signifie que la VM supporte seulement jusqu'à 256 variables locales dans la portée à la fois.

Si nous essayons d'aller au-dessus de ça, non seulement ne pourrions-nous pas nous y référer à l'exécution, mais le compilateur écraserait son propre tableau de locales, aussi. Empêchons cela.

^code too-many-locals (1 before, 1 after)

Le cas suivant est plus délicat. Considérez :

```lox
{
  var a = "first";
  var a = "second";
}
```

Au niveau supérieur, Lox permet de redéclarer une variable avec le même nom qu'une déclaration précédente parce que c'est utile pour le REPL. Mais à l'intérieur d'une portée locale, c'est une chose assez <span name="rust">bizarre</span> à faire. C'est susceptible d'être une erreur, et beaucoup de langages, incluant notre propre Lox, consacrent cette supposition en faisant de ceci une erreur.

<aside name="rust">

Intéressamment, le langage de programmation Rust _permet_ bien ceci, et le code idiomatique repose dessus.

</aside>

Notez que le programme ci-dessus est différent de celui-ci :

```lox
{
  var a = "outer";
  {
    var a = "inner";
  }
}
```

C'est OK d'avoir deux variables avec le même nom dans des portées _différentes_, même quand les portées se chevauchent de telle sorte que les deux sont visibles en même temps. C'est le masquage (shadowing), et Lox permet bien cela. C'est seulement une erreur d'avoir deux variables avec le même nom dans la _même_ portée locale.

Nous détectons cette erreur comme ceci :

^code existing-in-scope (1 before, 2 after)

<aside name="negative">

Ne vous inquiétez pas à propos de cette partie bizarre `depth != -1` encore. Nous arriverons à de quoi il s'agit plus tard.

</aside>

Les variables locales sont ajoutées au tableau quand elles sont déclarées, ce qui signifie que la portée courante est toujours à la fin du tableau. Quand nous déclarons une nouvelle variable, nous commençons à la fin et travaillons en arrière, cherchant une variable existante avec le même nom. Si nous en trouvons une dans la portée courante, nous rapportons l'erreur. Sinon, si nous atteignons le début du tableau ou une variable possédée par une autre portée, alors nous savons que nous avons vérifié toutes les variables existantes dans la portée.

Pour voir si deux identifiants sont les mêmes, nous utilisons ceci :

^code identifiers-equal

Puisque nous connaissons les longueurs des deux léxèmes, nous vérifions cela d'abord. Cela échouera rapidement pour beaucoup de chaînes non-égales. Si les <span name="hash">longueurs</span> sont les mêmes, nous vérifions les caractères en utilisant `memcmp()`. Pour accéder à `memcmp()`, nous avons besoin d'un include.

<aside name="hash">

Ce serait une petite optimisation sympa si nous pouvions vérifier leurs hachages, mais les jetons ne sont pas des LoxStrings complètes, donc nous n'avons pas calculé leurs hachages encore.

</aside>

^code compiler-include-string (1 before, 2 after)

Avec ceci, nous sommes capables d'amener des variables à l'existence. Mais, comme des fantômes, elles s'attardent au-delà de la portée où elles sont déclarées. Quand un bloc finit, nous avons besoin de les mettre au repos.

^code pop-locals (1 before, 1 after)

Quand nous dépilons une portée, nous marchons en arrière à travers le tableau local cherchant toutes variables déclarées à la profondeur de portée que nous venons de quitter. Nous les jetons en décrémentant simplement la longueur du tableau.

Il y a un composant d'exécution à ceci aussi. Les variables locales occupent des emplacements sur la pile. Quand une variable locale sort de la portée, cet emplacement n'est plus nécessaire et devrait être libéré. Donc, pour chaque variable que nous jetons, nous émettons aussi une <span name="pop">instruction</span> `OP_POP` pour la dépiler de la pile.

<aside name="pop">

Quand de multiples variables locales sortent de la portée à la fois, vous obtenez une série d'instructions `OP_POP` qui sont interprétées une à la fois. Une optimisation simple que vous pourriez ajouter à votre implémentation Lox est une instruction `OP_POPN` spécialisée qui prend un opérande pour le nombre d'emplacements à dépiler et les dépile tous à la fois.

</aside>

## Utiliser les Locales

Nous pouvons maintenant compiler et exécuter des déclarations de variable locale. À l'exécution, leurs valeurs sont assises là où elles devraient être sur la pile. Commençons à les utiliser. Nous ferons à la fois l'accès variable et l'affectation en même temps puisqu'ils touchent les mêmes fonctions dans le compilateur.

Nous avons déjà du code pour obtenir et définir les variables globales, et -- comme de bons petits ingénieurs logiciels -- nous voulons réutiliser autant de ce code existant que nous le pouvons. Quelque chose comme ceci :

^code named-local (1 before, 2 after)

Au lieu de coder en dur les instructions bytecode émises pour l'accès variable et l'affectation, nous utilisons une couple de variables C. D'abord, nous essayons de trouver une variable locale avec le nom donné. Si nous en trouvons une, nous utilisons les instructions pour travailler avec les locales. Sinon, nous supposons que c'est une variable globale et utilisons les instructions bytecode existantes pour les globales.

Un peu plus bas, nous utilisons ces variables pour émettre les bonnes instructions. Pour l'affectation :

^code emit-set (2 before, 1 after)

Et pour l'accès :

^code emit-get (2 before, 1 after)

Le vrai cœur de ce chapitre, la partie où nous résolvons une variable locale, est ici :

^code resolve-local

Pour tout ça, c'est direct. Nous marchons la liste des locales qui sont actuellement dans la portée. Si l'une a le même nom que le jeton identifiant, l'identifiant doit faire référence à cette variable. Nous l'avons trouvée ! Nous marchons le tableau en arrière pour que nous trouvions la _dernière_ variable déclarée avec l'identifiant. Cela assure que les variables locales intérieures masquent correctement les locales avec le même nom dans les portées environnantes.

À l'exécution, nous chargeons et stockons les locales en utilisant l'index d'emplacement de pile, donc c'est ce que le compilateur a besoin de calculer après qu'il a résolu la variable. Chaque fois qu'une variable est déclarée, nous l'ajoutons au tableau de locales dans Compiler. Cela signifie que la première variable locale est à l'index zéro, la suivante est à l'index un, et ainsi de suite. En d'autres termes, le tableau de locales dans le compilateur a la _mëme_ disposition exacte que la pile de la VM aura à l'exécution. L'index de la variable dans le tableau de locales est le même que son emplacement de pile. Comme c'est commode !

Si nous traversons le tableau entier sans trouver une variable avec le nom donné, ce ne doit pas être une locale. Dans ce cas, nous renvoyons `-1` pour signaler que ça n'a pas été trouvé et devrait être supposé être une variable globale à la place.

### Interpréter les variables locales

Notre compilateur émet deux nouvelles instructions, donc mettons-les en marche. D'abord est le chargement d'une variable locale :

^code get-local-op (1 before, 1 after)

Et son implémentation :

^code interpret-get-local (1 before, 1 after)

Elle prend un opérande d'un octet unique pour l'emplacement de pile où la locale vit. Elle charge la valeur depuis cet index et la pousse ensuite au sommet de la pile où les instructions ultérieures peuvent la trouver.

<aside name="slot">

Il semble redondant de pousser la valeur de la locale sur la pile puisqu'elle est déjà sur la pile plus bas quelque part. Le problème est que les autres instructions bytecode cherchent seulement les données au _sommet_ de la pile. C'est l'aspect central qui rend notre jeu d'instructions bytecode basé sur la _pile_. Les jeux d'instructions bytecode [basés sur des registres][reg] évitent cette jonglerie de pile au coût d'avoir des instructions plus grandes avec plus d'opérandes.

[reg]: machine-virtuelle.html#note-de-conception

</aside>

Ensuite est l'affectation :

^code set-local-op (1 before, 1 after)

Vous pouvez probablement prédire l'implémentation.

^code interpret-set-local (1 before, 1 after)

Elle prend la valeur affectée du sommet de la pile et la stocke dans l'emplacement de pile correspondant à la variable locale. Notez qu'elle ne dépile pas la valeur de la pile. Rappelez-vous, l'affectation est une expression, et chaque expression produit une valeur. La valeur d'une expression d'affectation est la valeur affectée elle-même, donc la VM laisse juste la valeur sur la pile.

Notre désassembleur est incomplet sans support pour ces deux nouvelles instructions.

^code disassemble-local (1 before, 1 after)

Le compilateur compile les variables locales vers un accès direct par emplacement. Le nom de la variable locale ne quitte jamais le compilateur pour entrer dans le fragment du tout. C'est génial pour la performance, mais pas si génial pour l'introspection. Quand nous désassemblons ces instructions, nous ne pouvons pas montrer le nom de la variable comme nous le pouvions avec les globales. Au lieu de cela, nous montrons juste le numéro d'emplacement.

<aside name="debug">

Effacer les noms de variables locales dans le compilateur est un vrai problème si nous voulons jamais implémenter un débogueur pour notre VM. Quand les utilisateurs marchent à travers le code, ils s'attendent à voir les valeurs des variables locales organisées par leurs noms. Pour supporter cela, nous aurions besoin de sortir quelque information supplémentaire qui suit le nom de chaque variable locale à chaque emplacement de pile.

</aside>

^code byte-instruction

### Un autre cas limite de portée

Nous avons déjà investi du temps à gérer une couple de cas limites bizarres autour des portées. Nous nous sommes assurés que le masquage fonctionne correctement. Nous rapportons une erreur si deux variables dans la même portée locale ont le même nom. Pour des raisons qui ne sont pas entièrement claires pour moi, la portée variable semble avoir beaucoup de ces rides. Je n'ai jamais vu un langage où cela semble complètement <span name="elegant">élégant</span>.

<aside name="elegant">

Non, pas même Scheme.

</aside>

Nous avons un cas limite de plus à traiter avant que nous finissions ce chapitre. Rappelez-vous cette étrange bête que nous avons rencontrée pour la première fois dans [l'implémentation de jlox de la résolution de variable][shadow] :

[shadow]: résolution-et-liaison.html#résoudre-les-déclarations-de-variables

```lox
{
  var a = "outer";
  {
    var a = a;
  }
}
```

Nous l'avons tuée alors en séparant la déclaration d'une variable en deux phases, et nous ferons cela ici encore :

<img src="image/local-variables/phases.png" alt="Un exemple de déclaration de variable marqué 'déclaré non initialisé' avant le nom de variable et 'prêt à l'emploi' après l'initialisateur." />

Dès que la déclaration de variable commence -- en d'autres termes, avant son initialisateur -- le nom est déclaré dans la portée courante. La variable existe, mais dans un état spécial "non initialisé". Ensuite nous compilons l'initialisateur. Si à n'importe quel point dans cette expression nous résolvons un identifiant qui pointe vers cette variable, nous verrons qu'elle n'est pas initialisée encore et rapporterons une erreur. Après que nous finissons de compiler l'initialisateur, nous marquons la variable comme initialisée et prête à l'emploi.

Pour implémenter cela, quand nous déclarons une locale, nous avons besoin d'indiquer l'état "non initialisé" d'une manière ou d'une autre. Nous pourrions ajouter un nouveau champ à Local, mais soyons un peu plus parcimonieux avec la mémoire. Au lieu de cela, nous réglerons la profondeur de portée de la variable à une valeur sentinelle spéciale, `-1`.

^code declare-undefined (1 before, 1 after)

Plus tard, une fois que l'initialisateur de la variable a été compilé, nous la marquons initialisée.

^code define-local (1 before, 2 after)

Cela est implémenté comme ceci :

^code mark-initialized

Donc c'est _vraiment_ ce que "déclarer" et "définir" une variable signifie dans le compilateur. "Déclarer" est quand la variable est ajoutée à la portée, et "définir" est quand elle devient disponible à l'utilisation.

Quand nous résolvons une référence à une variable locale, nous vérifions la profondeur de portée pour voir si elle est complètement définie.

^code own-initializer-error (1 before, 1 after)

Si la variable a la profondeur sentinelle, ce doit être une référence à une variable dans son propre initialisateur, et nous rapportons cela comme une erreur.

C'est tout pour ce chapitre ! Nous avons ajouté des blocs, des variables locales, et une vraie portée lexicale pour de vrai. Étant donné que nous avons introduit une représentation d'exécution entièrement différente pour les variables, nous n'avons pas eu à écrire beaucoup de code. L'implémentation a fini par être assez propre et efficace.

Vous noterez que presque tout le code que nous avons écrit est dans le compilateur. Là-bas dans le runtime, c'est juste deux petites instructions. Vous verrez ceci comme une <span name="static">tendance</span> continue dans clox comparé à jlox. Un des plus gros marteaux dans la boîte à outils de l'optimiseur est de tirer le travail vers l'avant dans le compilateur pour que vous n'ayez pas à le faire à l'exécution. Dans ce chapitre, cela signifiait résoudre exactement quel emplacement de pile chaque variable locale occupe. De cette façon, à l'exécution, aucune recherche ou résolution n'a besoin d'arriver.

<aside name="static">

Vous pouvez regarder les types statiques comme un exemple extrême de cette tendance. Un langage typé statiquement prend toute l'analyse de type et la gestion d'erreur de type et trie tout ça pendant la compilation. Ensuite le runtime n'a pas à gaspiller de temps à vérifier que les valeurs ont le type propre pour leur opération. En fait, dans certains langages typés statiquement comme C, vous ne _connaissez_ même pas le type à l'exécution. Le compilateur efface complètement toute représentation du type d'une valeur laissant juste les bits nus.

</aside>

<div class="challenges">

## Défis

1.  Notre simple tableau local rend facile le calcul de l'emplacement de pile de chaque variable locale. Mais cela signifie que quand le compilateur résout une référence à une variable, nous devons faire un scan linéaire à travers le tableau.

    Trouvez quelque chose de plus efficace. Pensez-vous que la complexité supplémentaire en vaut la peine ?

2.  Comment d'autres langages gèrent-ils le code comme ceci :

    ```lox
    var a = a;
    ```

    Que feriez-vous si c'était votre langage ? Pourquoi ?

3.  Beaucoup de langages font une distinction entre des variables qui peuvent être réassignées et celles qui ne le peuvent pas. En Java, le modificateur `final` vous empêche d'assigner à une variable. En JavaScript, une variable déclarée avec `let` peut être assignée, mais une déclarée utilisant `const` ne le peut pas. Swift traite `let` comme assignation unique et utilise `var` pour les variables assignables. Scala et Kotlin utilisent `val` et `var`.

    Choisissez un mot-clé pour une forme de variable à assignation unique à ajouter à Lox. Justifiez votre choix, puis implémentez-le. Une tentative d'assigner à une variable déclarée en utilisant votre nouveau mot-clé devrait causer une erreur de compilation.

4.  Étendez clox pour permettre à plus de 256 variables locales d'être dans la portée à la fois.

</div>
