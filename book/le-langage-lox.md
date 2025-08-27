> Quelle plus belle chose pouvez-vous faire pour quelqu’un que de lui préparer le petit déjeuner ?
>
> <cite>Anthony Bourdain</cite>

Nous allons passer le reste de ce livre à éclairer chaque recoin sombre et
varié du langage Lox, mais il semblerait cruel de vous faire commencer
immédiatement à écrire du code pour l’interpréteur sans au moins un aperçu
de ce que nous allons obtenir au final.

En même temps, je ne veux pas vous entraîner à travers des pages et des
pages de jargon juridique de langage et de spécifications avant que vous ne
puissiez toucher à votre <span name="home">éditeur</span> de texte. Ce sera donc
une introduction douce et amicale à Lox. Elle laissera de côté beaucoup de
détails et de cas particuliers. Nous aurons largement le temps pour cela plus
tard.

<aside name="home">

Un tutoriel n’est pas très amusant si vous ne pouvez pas essayer le code vous-même.
Hélas, vous n’avez pas encore d’interpréteur Lox, puisque vous n’en avez pas construit un !

N’ayez crainte. Vous pouvez utiliser [le mien][repo].

[repo]: https://github.com/munificent/craftinginterpreters

</aside>

## Hello, Lox

Voici votre tout premier avant-goût de <span name="salmon">Lox</span> :

<aside name="salmon">

Votre premier avant-goût de Lox, le langage, bien sûr. Je ne sais pas si vous
avez déjà goûté au saumon fumé à froid et salé. Si ce n’est pas le cas, essayez
aussi.

</aside>

```lox
// Your first Lox program!
print "Hello, world!";
```

Comme le suggèrent le commentaire de ligne `//` et le point-virgule final, la
syntaxe de Lox appartient à la famille des langages C. (Il n’y a pas de
parenthèses autour de la chaîne car `print` est une instruction intégrée, et non
une fonction de bibliothèque.)

Je ne prétendrai pas que <span name="c">C</span> ait une *excellente* syntaxe.
Si nous voulions quelque chose d’élégant, nous imiterions probablement Pascal ou
Smalltalk. Si nous voulions aller jusqu’au minimalisme façon
« mobilier scandinave », nous ferions un Scheme. Tous ont leurs vertus.

<aside name="c">

Je suis sûrement biaisé, mais je pense que la syntaxe de Lox est plutôt propre.
Les problèmes de grammaire les plus flagrants de C concernent les types.
Dennis Ritchie avait cette idée appelée
« [la déclaration reflète l’utilisation][use] », où les déclarations de variables
reflètent les opérations que vous devriez effectuer sur la variable pour obtenir
une valeur du type de base. Idée astucieuse, mais je ne pense pas qu’elle ait
très bien fonctionné en pratique.

[use]: http://softwareengineering.stackexchange.com/questions/117024/why-was-the-c-syntax-for-arrays-pointers-and-functions-designed-this-way

Lox n’a pas de types statiques, donc nous évitons cela.

</aside>

Ce que la syntaxe de type C offre à la place, c’est quelque chose que vous
trouverez souvent plus précieux dans un langage : *la familiarité*. Je sais que
vous êtes déjà à l’aise avec ce style parce que les deux langages que nous
utiliserons pour *implémenter* Lox -- Java et C -- l’héritent aussi. Utiliser
une syntaxe similaire pour Lox vous donne une chose de moins à apprendre.

## Un langage de haut niveau

Bien que ce livre soit finalement plus long que je ne l’espérais, il n’est
toujours pas assez volumineux pour contenir un langage énorme comme Java. Afin
de tenir deux implémentations complètes de Lox dans ces pages, Lox lui-même
doit être assez compact.

Quand je pense aux langages petits mais utiles, me viennent à l’esprit des
langages de "script" de haut niveau comme <span name="js">JavaScript</span>,
Scheme et Lua. Parmi ces trois, Lox ressemble le plus à JavaScript, principalement
parce que la plupart des langages à syntaxe C le font. Comme nous l’apprendrons
plus tard, l’approche de Lox pour la portée des variables est proche de Scheme.
La saveur C de Lox que nous construirons dans [Partie III][] doit beaucoup à
l’implémentation propre et efficace de Lua.

[part iii]: a-bytecode-virtual-machine.html

<aside name="js">

Maintenant que JavaScript a conquis le monde et est utilisé pour construire des
applications gigantesques, il est difficile de le considérer comme un "petit
langage de script". Mais Brendan Eich a bricolé le premier interpréteur JS dans
Netscape Navigator en *dix jours* pour faire animer des boutons sur les pages
web. JavaScript a bien grandi depuis, mais c’était autrefois un petit langage
mignon.

Parce qu’Eich a assemblé JS avec à peu près les mêmes matériaux bruts et le
même temps qu’un épisode de MacGyver, il y a quelques coins sémantiques bizarres
où le ruban adhésif et les trombones transparaissent. Des choses comme le
hoisting de variables, `this` lié dynamiquement, les trous dans les tableaux et
les conversions implicites.

J’ai eu le luxe de prendre mon temps sur Lox, donc il devrait être un peu plus
propre.

</aside>

Lox partage deux autres aspects avec ces trois langages :

### Typage dynamique

Lox est dynamiquement typé. Les variables peuvent stocker des valeurs de
n’importe quel type, et une seule variable peut même contenir des valeurs de
types différents à différents moments. Si vous essayez d’effectuer une
opération sur des valeurs du mauvais type -- par exemple, diviser un nombre par
une chaîne -- l’erreur est détectée et signalée à l’exécution.

Il y a beaucoup de raisons d’aimer les types <span name="static">statiques</span>,
mais elles ne l’emportent pas sur les raisons pragmatiques de choisir des types
dynamiques pour Lox. Un système de types statique représente beaucoup de travail
à apprendre et à implémenter. L’éviter vous donne un langage plus simple et un
livre plus court. Nous pourrons faire exécuter notre interpréteur plus rapidement
si nous reportons la vérification des types à l’exécution.

<aside name="static">

Après tout, les deux langages que nous utiliserons pour *implémenter* Lox sont
tous deux statiquement typés.

</aside>

### Gestion automatique de la mémoire

Les langages de haut niveau existent pour éliminer les tâches laborieuses et
sujettes aux erreurs de bas niveau, et quoi de plus fastidieux que de gérer
manuellement l’allocation et la libération de la mémoire ? Personne ne se lève
en saluant le soleil du matin en disant : « J’ai hâte de trouver le bon endroit
pour appeler `free()` pour chaque octet de mémoire que j’alloue aujourd’hui ! »

Il existe deux principales <span name="gc">techniques</span> pour gérer la mémoire :
**comptage de références** et **ramasse-miettes par traçage** (généralement
appelé simplement **garbage collection** ou **GC**). Les compteurs de références
sont beaucoup plus simples à implémenter -- je pense que c’est pour cela que
Perl, PHP et Python ont tous commencé par les utiliser. Mais, avec le temps, les
limitations du comptage de références deviennent trop contraignantes. Tous ces
langages ont fini par ajouter un vrai GC par traçage, ou au moins suffisamment
pour nettoyer les cycles d’objets.

<aside name="gc">

En pratique, le comptage de références et le traçage sont plus les extrémités
d’un continuum que des côtés opposés. La plupart des systèmes de comptage de
références finissent par faire un peu de traçage pour gérer les cycles, et les
barrières d’écriture d’un collecteur générationnel ressemblent un peu à des appels
de `retain` si on plisse les yeux.

Pour en savoir plus, voir "[A Unified Theory of Garbage Collection][gc]" (PDF).

[gc]: https://researcher.watson.ibm.com/researcher/files/us-bacon/Bacon04Unified.pdf

</aside>

Le ramasse-miettes par traçage a une réputation redoutable. Travailler au niveau
de la mémoire brute est *un peu effrayant*. Déboguer un GC peut parfois vous
laisser voir des dumps hexadécimaux dans vos rêves. Mais rappelez-vous, ce livre
vise à dissiper la magie et à terrasser ces monstres, donc nous allons *écrire
notre propre ramasse-miettes*. Je pense que vous trouverez l’algorithme assez
simple et très amusant à implémenter.

## Types de données

Dans le petit univers de Lox, les atomes qui composent toute matière sont les
types de données intégrés. Il n’y en a que quelques-uns :

*   **<span name="bool">Booléens</span>.** On ne peut pas coder sans logique
    et on ne peut pas faire de logique sans valeurs booléennes. "True" et
    "false", le yin et le yang du logiciel. Contrairement à certains langages
    anciens qui réutilisent un type existant pour représenter la vérité et le
    faux, Lox a un type Booléen dédié. Nous pouvons être en mode expédition
    rudimentaire, mais nous ne sommes pas des *sauvages*.

    <aside name="bool">

    Les variables booléennes sont le seul type de données dans Lox nommé d’après
    une personne, George Boole, c’est pourquoi "Boolean" est en majuscule. Il
    est mort en 1864, près d’un siècle avant que les ordinateurs numériques ne
    transforment son algèbre en électricité. Je me demande ce qu’il penserait de
    voir son nom sur des milliards de lignes de code Java.

    </aside>

    Il y a évidemment deux valeurs booléennes, et un littéral pour chacune.

    ```lox
    true;  // Not false.
    false; // Not *not* false.
    ```

*   **Nombres.** Lox n’a qu’un seul type de nombre : le nombre à virgule flottante
    en double précision. Comme les nombres flottants peuvent également représenter
    une large gamme d’entiers, cela couvre beaucoup de terrain tout en gardant
    les choses simples.

    Les langages complets disposent de beaucoup de syntaxe pour les nombres --
    hexadécimal, notation scientifique, octal, toutes sortes de choses amusantes.
    Nous nous contenterons des littéraux entiers et décimaux de base.

    ```lox
    1234;  // An integer.
    12.34; // A decimal number.
    ```

*   **Chaînes de caractères.** Nous avons déjà vu un littéral de chaîne dans le
    premier exemple. Comme dans la plupart des langages, elles sont encadrées
    par des guillemets doubles.

    ```lox
    "I am a string";
    "";    // The empty string.
    "123"; // This is a string, not a number.
    ```

    Comme nous le verrons lorsque nous les implémenterons, il y a pas mal de
complexité cachée dans cette innocente séquence de <span name="char">caractères</span>.

<aside name="char">

Même le mot "caractère" est trompeur. Est-ce de l'ASCII ? Unicode ? Un point
de code ou un "grapheme cluster" ? Comment les caractères sont-ils codés ? Chaque
caractère a-t-il une taille fixe, ou peut-elle varier ?

</aside>

*   **Nil.** Il y a une dernière valeur intégrée qui n'est jamais invitée à la
    fête mais semble toujours apparaître. Elle représente "aucune valeur". Elle
    s'appelle "null" dans de nombreux autres langages. Dans Lox, nous l'écrivons
    `nil`. (Lorsque nous l'implémenterons, cela aidera à distinguer le `nil` de
    Lox du `null` de Java ou C.)

Il y a de bons arguments pour ne pas avoir de valeur nulle dans un langage,
puisque les erreurs de pointeur nul sont le fléau de notre industrie. Si nous
avions un langage statiquement typé, cela vaudrait la peine d'essayer de l'interdire.
Dans un langage dynamiquement typé, cependant, l'éliminer est souvent plus ennuyeux
que de l'avoir.

## Expressions

Si les types de données intégrés et leurs littéraux sont des atomes, alors
les **expressions** doivent être les molécules. La plupart d'entre elles vous
seront familières.

### Arithmétique

Lox propose les opérateurs arithmétiques de base que vous connaissez et
appréciez depuis C et d'autres langages :


```lox
add + me;
subtract - me;
multiply * me;
divide / me;
```

Les sous-expressions de chaque côté de l'opérateur sont des **opérandes**. Comme
il y en a *deux*, on les appelle des opérateurs **binaires**. (Cela n'a rien à voir
avec l'utilisation de "binaire" pour les uns et les zéros.) Comme l'opérateur est
<span name="fixity">fixé</span> *au milieu* des opérandes, on les appelle aussi
des opérateurs **infixes** (par opposition aux opérateurs **préfixes** où
l'opérateur précède les opérandes, et **postfixes** où il les suit).

<aside name="fixity">

Il existe quelques opérateurs qui ont plus de deux opérandes et les opérateurs
sont intercalés entre elles. Le seul d'usage répandu est l'opérateur "conditionnel"
ou "ternaire" de C et ses amis :

```c
condition ? thenArm : elseArm;
```

Certains appellent ces opérateurs **mixfix**. Quelques langages permettent de
définir vos propres opérateurs et de contrôler leur positionnement -- leur
"fixité".

</aside>

Un opérateur arithmétique est en fait *à la fois* infixe et préfixe. L'opérateur `-`
peut également être utilisé pour négativer un nombre.

```lox
-negateMe;
```

Tous ces opérateurs fonctionnent sur des nombres, et il est erroné de leur passer
d'autres types. L'exception est l'opérateur `+` -- vous pouvez aussi lui passer
deux chaînes pour les concaténer.

### Comparaison et égalité

Continuons, nous avons quelques opérateurs supplémentaires qui renvoient toujours
un résultat booléen. Nous pouvons comparer des nombres (et seulement des nombres)
en utilisant les Vieux Opérateurs de Comparaison.

```lox
less < than;
lessThan <= orEqual;
greater > than;
greaterThan >= orEqual;
```

Nous pouvons tester l'égalité ou l'inégalité de deux valeurs de n'importe quel type.

```lox
1 == 2;         // false.
"cat" != "dog"; // true.
```

Même de types différents.

```lox
314 == "pi"; // false.
```

Les valeurs de types différents ne sont *jamais* équivalentes.

```lox
123 == "123"; // false.
```

Je suis généralement contre les conversions implicites.

### Opérateurs logiques

L'opérateur not, un préfixe `!`, renvoie `false` si son opérande est vrai, et vice versa.

```lox
!true;  // false.
!false; // true.
```

Les deux autres opérateurs logiques sont en réalité des constructions de flux de contrôle déguisées en expressions. Une expression <span name="and">`and`</span> détermine si deux valeurs sont *toutes deux* vraies. Elle renvoie l'opérande de gauche si elle est fausse, ou l'opérande de droite sinon.

```lox
true and false; // false.
true and true;  // true.
```

Et une expression `or` détermine si *l'une ou l'autre* des deux valeurs (ou les deux) est vraie. Elle renvoie l'opérande de gauche si elle est vraie, et l'opérande de droite sinon.

```lox
false or false; // false.
true or false;  // true.
```

<aside name="and">

J'ai utilisé `and` et `or` pour ceux-ci au lieu de `&&` et `||` parce que Lox n'utilise pas `&` et `|` pour les opérateurs binaires. Cela m'aurait paru étrange d'introduire les formes à deux caractères sans les formes à un seul caractère.

J'aime aussi un peu utiliser des mots pour ceux-ci, car ce sont vraiment des structures de contrôle et non de simples opérateurs.

</aside>

La raison pour laquelle `and` et `or` ressemblent à des structures de contrôle est qu'ils **court-circuitent**. Non seulement `and` renvoie l'opérande de gauche si elle est fausse, mais il n'*évalue* même pas l'opérande de droite dans ce cas. Inversement (contrapositivement ?), si l'opérande de gauche d'un `or` est vraie, la droite est ignorée.

### Précedence et regroupement

Tous ces opérateurs ont la même précédence et associativité que ce à quoi vous vous attendez venant de C. (Lorsque nous aborderons l'analyse syntaxique, nous serons *beaucoup* plus précis à ce sujet.) Dans les cas où la précédence n'est pas ce que vous voulez, vous pouvez utiliser `()` pour regrouper des éléments.

```lox
var average = (min + max) / 2;
```

Comme elles ne sont pas très intéressantes techniquement, j'ai supprimé le reste de la ménagerie typique des opérateurs de notre petit langage. Pas d'opérateurs bit à bit, de décalage, modulo ou conditionnels. Je ne vous note pas, mais vous gagnerez des points bonus dans mon cœur si vous ajoutez ces opérateurs à votre propre implémentation de Lox.

Ce sont les formes d'expressions (sauf quelques-unes liées à des fonctionnalités spécifiques que nous aborderons plus tard), passons donc à un niveau supérieur.

## Instructions

Nous en arrivons maintenant aux instructions. Là où la tâche principale d'une expression est de produire une *valeur*, la tâche d'une instruction est de produire un *effet*. Comme, par définition, les instructions ne renvoient pas de valeur, pour être utiles elles doivent autrement changer le monde d'une certaine manière — généralement en modifiant un état, en lisant une entrée ou en produisant une sortie.

Vous avez déjà vu quelques types d'instructions. La première était :

```lox
print "Hello, world!";
```

Une <span name="print">instruction `print`</span> évalue une seule expression et affiche le résultat à l'utilisateur. Vous avez également vu quelques instructions comme :

<aside name="print">

Intégrer `print` directement dans le langage au lieu d'en faire simplement une fonction de bibliothèque de base est un petit hack. Mais c'est un hack *utile* pour nous : cela signifie que notre interpréteur en cours de développement peut commencer à produire des sorties avant que nous ayons implémenté toute la machinerie nécessaire pour définir des fonctions, les rechercher par nom et les appeler.

</aside>

```lox
"some expression";
```

Une expression suivie d'un point-virgule (`;`) transforme l'expression en instruction. Cela s'appelle (de manière assez imaginative) une **instruction-expression**.

Si vous voulez regrouper une série d'instructions là où une seule est attendue, vous pouvez les envelopper dans un **bloc**.

```lox
{
  print "One statement.";
  print "Two statements.";
}
```

Les blocs influencent également la portée, ce qui nous amène à la section suivante...

## Variables

Vous déclarez des variables à l’aide d’instructions `var`. Si vous <span name="omit">omettrez</span> l’initialiseur, la valeur de la variable sera par défaut `nil`.

<aside name="omit">

C’est l’un de ces cas où l’absence de `nil` et l’obligation d’initialiser chaque variable à une valeur serait plus contraignante que de gérer `nil` lui-même.

</aside>

```lox
var imAVariable = "here is my value";
var iAmNil;
```

Une fois déclarée, vous pouvez naturellement accéder à une variable et lui
attribuer une valeur en utilisant son nom.

<span name="breakfast"></span>

```lox
var breakfast = "bagels";
print breakfast; // "bagels".
breakfast = "beignets";
print breakfast; // "beignets".
```

<aside name="breakfast">

Pouvez-vous deviner que j’ai tendance à travailler sur ce livre le matin avant
d’avoir mangé quoi que ce soit ?

</aside>

Je ne vais pas entrer dans les règles de portée des variables ici, car nous
allons passer un temps surprenant dans les chapitres suivants à cartographier
chaque centimètre carré de ces règles. Dans la plupart des cas, cela fonctionne
comme vous pourriez vous y attendre en venant de C ou Java.

## Contrôle de flux

Il est difficile d’écrire des programmes <span name="flow">utiles</span> si
vous ne pouvez pas sauter certains morceaux de code ou en exécuter d’autres
plusieurs fois. Cela signifie qu’il faut du contrôle de flux. En plus des
opérateurs logiques que nous avons déjà couverts, Lox reprend trois instructions
directement de C.

<aside name="flow">

Nous avons déjà `and` et `or` pour les branchements, et nous *pourrions* utiliser
la récursion pour répéter du code, donc théoriquement, cela suffirait. Mais ce
serait assez maladroit de programmer ainsi dans un langage à style impératif.

Scheme, en revanche, n’a pas de constructions intégrées pour les boucles. Il
s’appuie *effectivement* sur la récursion pour la répétition. Smalltalk, de son
côté, n’a pas non plus de structures intégrées pour les branchements, et repose
sur le *dynamic dispatch* pour exécuter sélectivement du code.

</aside>

Une instruction `if` exécute l’une des deux instructions en fonction d’une
condition.

```lox
if (condition) {
  print "yes";
} else {
  print "no";
}
```

Une boucle `while` <span name="do">(`loop`)</span> exécute le corps
répétitivement tant que l’expression de condition s’évalue à vrai.

```lox
var a = 1;
while (a < 10) {
  print a;
  a = a + 1;
}
```

<aside name="do">

J’ai laissé les boucles `do while` en dehors de Lox parce qu’elles ne sont pas
très courantes et ne vous apprendraient rien que vous n’apprendrez déjà avec
`while`. Allez-y et ajoutez-les à votre implémentation si cela vous fait
plaisir. C’est votre fête.

</aside>

Enfin, nous avons les boucles `for`.

```lox
for (var a = 1; a < 10; a = a + 1) {
  print a;
}
```

Cette boucle fait la même chose que la boucle `while` précédente.  
La plupart des langages modernes disposent aussi d’une sorte de boucle <span name="foreach">`for-in`</span> ou `foreach` permettant d’itérer explicitement sur différents types de séquences.  
Dans un vrai langage, c’est plus agréable que la boucle `for` à la C que nous avons ici.  
Lox reste basique.

<aside name="foreach">

C’est une concession que j’ai faite à cause de la manière dont l’implémentation est découpée en chapitres.  
Une boucle `for-in` nécessite une forme de *dynamic dispatch* dans le protocole des itérateurs pour gérer différents types de séquences, mais nous ne voyons cela qu’après avoir terminé le contrôle de flux.  
Nous pourrions revenir en arrière et ajouter les boucles `for-in` plus tard, mais je ne pensais pas que cela vous apprendrait quelque chose de particulièrement intéressant.

</aside>

## Fonctions

Une expression d’appel de fonction ressemble à ce que l’on trouve en C.

```lox
makeBreakfast(bacon, eggs, toast);
```

Vous pouvez également appeler une fonction sans lui passer d’argument.  

```lox
makeBreakfast();
```

Contrairement à Ruby par exemple, les parenthèses sont obligatoires dans ce cas.  
Si vous les omettez, le nom ne *fait pas appel* à la fonction, il ne fait que s’y référer.  

Un langage n’est pas très amusant si vous ne pouvez pas définir vos propres fonctions.  
En Lox, vous faites cela avec <span name="fun">`fun`</span>.  

<aside name="fun">

J’ai vu des langages qui utilisent `fn`, `fun`, `func` et `function`.  
J’espère encore tomber un jour sur un `funct`, `functi` ou `functio`.

</aside>

```lox
fun printSum(a, b) {
  print a + b;
}
```

C’est le bon moment pour clarifier un peu de <span name="define">terminologie</span>.  
Certaines personnes utilisent « paramètre » et « argument » comme s’ils étaient interchangeables et, pour beaucoup, ils le sont.  
Mais nous allons passer pas mal de temps à couper les cheveux en quatre sur des questions de sémantique, donc autant être précis dans nos mots.  
À partir de maintenant :

*   Un **argument** est une valeur réelle que vous passez à une fonction lorsque vous l’appelez.  
    Ainsi, un *appel* de fonction possède une liste d’*arguments*.  
    Parfois, on parle de **paramètre effectif** pour désigner ceux-ci.

*   Un **paramètre** est une variable qui contient la valeur de l’argument à l’intérieur du corps de la fonction.  
    Ainsi, une *déclaration* de fonction possède une liste de *paramètres*.  
    D’autres les appellent **paramètres formels** ou simplement **formels**.

<aside name="define">

En parlant de terminologie, certains langages statiquement typés comme C font une distinction entre *déclarer* une fonction et la *définir*.  
Une déclaration associe le type de la fonction à son nom, afin que les appels puissent être vérifiés par le compilateur, mais elle ne fournit pas de corps.  
Une définition déclare la fonction et fournit également son corps, ce qui permet de la compiler.

Comme Lox est dynamiquement typé, cette distinction n’a pas lieu d’être.  
Une déclaration de fonction en Lox spécifie entièrement la fonction, y compris son corps.

</aside>

Le corps d’une fonction est toujours un bloc.  
À l’intérieur, vous pouvez retourner une valeur à l’aide de l’instruction `return`.

```lox
fun returnSum(a, b) {
  return a + b;
}
```

Si l’exécution atteint la fin du bloc sans rencontrer de `return`, elle renvoie <span name="sneaky">implicitement</span> `nil`.

<aside name="sneaky">

Vous voyez, je vous avais dit que `nil` se glisserait quand on ne regarde pas.

</aside>

### Fermetures (Closures)

Les fonctions sont des valeurs *de première classe* dans Lox, ce qui signifie simplement que ce sont de vraies valeurs auxquelles vous pouvez faire référence, stocker dans des variables, passer en argument, etc.  
Cela fonctionne ainsi :

```lox
fun addPair(a, b) {
  return a + b;
}

fun identity(a) {
  return a;
}

print identity(addPair)(1, 2); // Prints "3".
```

Puisque les déclarations de fonctions sont des instructions, vous pouvez déclarer des fonctions locales à l'intérieur d'une autre fonction.

```lox
fun outerFunction() {
  fun localFunction() {
    print "I'm local!";
  }

  localFunction();
}
```

Si vous combinez fonctions locales, fonctions de première classe et portée des blocs, vous vous retrouvez dans cette situation intéressante :

```lox
fun returnFunction() {
  var outside = "outside";

  fun inner() {
    print outside;
  }

  return inner;
}

var fn = returnFunction();
fn();
```

Ici, `inner()` accède à une variable locale déclarée en dehors de son corps dans la
fonction environnante. Est-ce que c'est correct ? Maintenant que de nombreux langages ont emprunté
cette fonctionnalité à Lisp, vous connaissez probablement la réponse : oui.

Pour que cela fonctionne, `inner()` doit "s'accrocher" aux références de toutes les variables
environnantes qu'elle utilise afin qu'elles restent disponibles même après que la fonction externe
soit retournée. Nous appelons les fonctions qui font cela <span
name="closure">**fermetures**</span>. De nos jours, le terme est souvent utilisé pour *toute*
fonction de première classe, bien que ce soit en quelque sorte un terme impropre si la fonction
ne se trouve pas fermer sur des variables.

<aside name="closure">

Peter J. Landin a inventé le terme "closure". Oui, il a inventé pratiquement la moitié des
termes dans les langages de programmation. La plupart d'entre eux sont sortis d'un article
incroyable, "[The Next 700 Programming Languages][svh]".

[svh]: https://homepages.inf.ed.ac.uk/wadler/papers/papers-we-love/landin-next-700.pdf

Afin d'implémenter ce genre de fonctions, vous devez créer une structure de données
qui regroupe le code de la fonction et les variables environnantes dont elle a besoin.
Il a appelé cela une "closure" parce qu'elle *se ferme sur* et s'accroche aux
variables dont elle a besoin.

</aside>

Comme vous pouvez l'imaginer, implémenter ces fonctionnalités ajoute de la complexité car nous ne
pouvons plus supposer que la portée des variables fonctionne strictement comme une pile où les
variables locales s'évaporent au moment où la fonction retourne. Nous allons passer un moment
amusant à apprendre comment faire fonctionner ces mécanismes correctement et efficacement.

## Classes

Puisque Lox a un typage dynamique, une portée lexicale (en gros, de "bloc"), et des fermetures,
il est à peu près à mi-chemin d'être un langage fonctionnel. Mais comme vous le verrez, il est
*aussi* à peu près à mi-chemin d'être un langage orienté objet. Les deux paradigmes ont beaucoup
d'atouts, donc j'ai pensé que cela valait la peine de couvrir un peu de chacun.

Puisque les classes ont été critiquées pour ne pas être à la hauteur de leur battage médiatique,
laissez-moi d'abord expliquer pourquoi je les ai mises dans Lox et ce livre. Il y a vraiment deux
questions :

### Pourquoi un langage pourrait-il vouloir être orienté objet ?

Maintenant que les langages orientés objet comme Java ont vendu leur âme et ne jouent que dans des
salles d'arène, ce n'est plus cool de les aimer. Pourquoi quelqu'un créerait-il un *nouveau*
langage avec des objets ? N'est-ce pas comme sortir de la musique sur des 8-pistes ?

Il est vrai que la frénésie "tout héritage tout le temps" des années 90 a produit des hiérarchies
de classes monstrueuses, mais la **programmation orientée objet** (**POO**) est encore plutôt
géniale. Des milliards de lignes de code réussi ont été écrites dans des langages POO, livrant
des millions d'applications à des utilisateurs heureux. Probablement qu'une majorité des
programmeurs qui travaillent aujourd'hui utilisent un langage orienté objet. Ils ne peuvent pas
tous se tromper *à ce point*.

En particulier, pour un langage typé dynamiquement, les objets sont plutôt pratiques. Nous avons
besoin de *quelque* moyen de définir des types de données composés pour regrouper des blobs de
trucs ensemble.

Si nous pouvons aussi accrocher des méthodes à ceux-ci, alors nous évitons le besoin de préfixer
toutes nos fonctions avec le nom du type de données sur lequel elles opèrent pour éviter d'entrer
en collision avec des fonctions similaires pour différents types. Dans, disons, Racket, vous
finissez par devoir nommer vos fonctions comme `hash-copy` (pour copier une table de hachage) et
`vector-copy` (pour copier un vecteur) afin qu'elles ne se marchent pas dessus. Les méthodes sont
délimitées à l'objet, donc ce problème disparaît.

### Pourquoi Lox est-il orienté objet ?

Je pourrais prétendre que les objets sont géniaux mais quand même hors du périmètre du livre. La
plupart des livres sur les langages de programmation, en particulier ceux qui essaient
d'implémenter un langage complet, laissent les objets de côté. Pour moi, cela signifie que le
sujet n'est pas bien couvert. Avec un paradigme si répandu, cette omission me rend triste.

Étant donné combien d'entre nous passent toute la journée à *utiliser* des langages POO, il
semble que le monde pourrait utiliser un peu de documentation sur comment en *faire* un. Comme
vous le verrez, il s'avère que c'est plutôt intéressant. Pas aussi difficile que vous pourriez
le craindre, mais pas aussi simple que vous pourriez le présumer non plus.

### Classes ou prototypes

Quand il s'agit d'objets, il y a en fait deux approches, les [classes][] et les [prototypes][].
Les classes sont venues en premier, et sont plus courantes grâce à C++, Java, C#, et leurs amis.
Les prototypes étaient une ramification pratiquement oubliée jusqu'à ce que JavaScript prenne
accidentellement le contrôle du monde.

[classes]: https://en.wikipedia.org/wiki/Class-based_programming
[prototypes]: https://en.wikipedia.org/wiki/Prototype-based_programming

Dans les langages basés sur les classes, il y a deux concepts centraux : les instances et les
classes. Les instances stockent l'état de chaque objet et ont une référence à la classe de
l'instance. Les classes contiennent les méthodes et la chaîne d'héritage. Pour appeler une
méthode sur une instance, il y a toujours un niveau d'indirection. Vous <span
name="dispatch">cherchez</span> la classe de l'instance et puis vous trouvez la méthode
*là* :

<aside name="dispatch">

Dans un langage typé statiquement comme C++, la recherche de méthode se fait typiquement au
moment de la compilation basée sur le type *statique* de l'instance, vous donnant une
**répartition statique**. En contraste, la **répartition dynamique** cherche la classe de
l'objet instance actuel au moment de l'exécution. C'est ainsi que les méthodes virtuelles dans
les langages typés statiquement et toutes les méthodes dans un langage typé dynamiquement comme
Lox fonctionnent.

</aside>

<img src="image/the-lox-language/class-lookup.png" alt="How fields and methods are looked up on classes and instances" />

Les langages basés sur les prototypes <span name="blurry">fusionnent</span> ces deux concepts.
Il n'y a que des objets -- pas de classes -- et chaque objet individuel peut contenir
un état et des méthodes. Les objets peuvent hériter directement les uns des autres (ou "déléguer
à" dans le jargon prototypal) :

<aside name="blurry">

En pratique, la ligne entre les langages basés sur les classes et basés sur les prototypes
s'estompe. La notion de "fonction constructeur" de JavaScript [vous pousse assez fort][js new]
vers la définition d'objets ressemblant à des classes. Pendant ce temps, Ruby basé sur les classes
est parfaitement heureux de vous laisser attacher des méthodes à des instances individuelles.

[js new]: http://gameprogrammingpatterns.com/prototype.html#what-about-javascript

</aside>

<img src="image/the-lox-language/prototype-lookup.png" alt="How fields and methods are looked up in a prototypal system" />

Cela signifie que d'une certaine manière les langages prototypaux sont plus fondamentaux que
les classes. Ils sont vraiment chouettes à implémenter parce qu'ils sont *tellement* simples.
Aussi, ils peuvent exprimer beaucoup de modèles inhabituels dont les classes vous détournent.

Mais j'ai regardé *beaucoup* de code écrit dans des langages prototypaux -- incluant
[certains de ma propre conception][finch]. Savez-vous ce que les gens font généralement avec
tout le pouvoir et la flexibilité des prototypes ? ...Ils les utilisent pour réinventer
les classes.

[finch]: http://finch.stuffwithstuff.com/

Je ne sais pas *pourquoi* c'est ainsi, mais les gens semblent naturellement préférer un
style basé sur les classes (Classique ? Classe ?). Les prototypes *sont* plus simples dans
le langage, mais ils semblent accomplir cela seulement en <span name="waterbed">poussant</span>
la complexité sur l'utilisateur. Donc, pour Lox, nous épargnerons à nos utilisateurs cette
peine et intégrerons les classes directement.

<aside name="waterbed">

Larry Wall, l'inventeur/prophète de Perl appelle cela la "[théorie du matelas à eau][waterbed theory]".
Une certaine complexité est essentielle et ne peut être éliminée. Si vous la poussez vers le bas
à un endroit, elle gonfle à un autre.

[waterbed theory]: http://wiki.c2.com/?WaterbedTheory

Les langages prototypaux n'*éliminent* pas tant la complexité des classes qu'ils ne font
que l'utilisateur prenne cette complexité en construisant ses propres bibliothèques de
métaprogrammation ressemblant à des classes.

</aside>

### Classes dans Lox

Assez de justification, voyons ce que nous avons réellement. Les classes englobent une
constellation de fonctionnalités dans la plupart des langages. Pour Lox, j'ai sélectionné
ce que je pense être les étoiles les plus brillantes. Vous déclarez une classe et ses
méthodes comme ceci :

```lox
class Breakfast {
  cook() {
    print "Eggs a-fryin'!";
  }

  serve(who) {
    print "Enjoy your breakfast, " + who + ".";
  }
}
```

Le corps d'une classe contient ses méthodes. Elles ressemblent à des déclarations de fonction
mais sans le mot-clé <span name="method">`fun`</span>. Quand la déclaration de classe
est exécutée, Lox crée un objet classe et le stocke dans une variable nommée d'après la
classe. Tout comme les fonctions, les classes sont de première classe dans Lox.

<aside name="method">

Elles sont quand même tout aussi amusantes (fun), cependant.

</aside>

```lox
// Store it in variables.
var someVariable = Breakfast;

// Pass it to functions.
someFunction(Breakfast);
```

Ensuite, nous avons besoin d'un moyen de créer des instances. Nous pourrions ajouter une sorte
de mot-clé `new`, mais pour garder les choses simples, dans Lox la classe elle-même est une
fonction factory pour les instances. Appelez une classe comme une fonction, et elle produit
une nouvelle instance d'elle-même.

```lox
var breakfast = Breakfast();
print breakfast; // "Breakfast instance".
```

### Instanciation et initialisation

Les classes qui n'ont que du comportement ne sont pas super utiles. L'idée derrière
la programmation orientée objet est d'encapsuler le comportement *et l'état* ensemble.
Pour faire cela, vous avez besoin de champs. Lox, comme d'autres langages typés
dynamiquement, vous permet d'ajouter librement des propriétés aux objets.

```lox
breakfast.meat = "sausage";
breakfast.bread = "sourdough";
```

Assigner à un champ le crée s'il n'existe pas déjà.

Si vous voulez accéder à un champ ou une méthode sur l'objet courant depuis une
méthode, vous utilisez le bon vieux `this`.

```lox
class Breakfast {
  serve(who) {
    print "Enjoy your " + this.meat + " and " +
        this.bread + ", " + who + ".";
  }

  // ...
}
```

Une partie de l'encapsulation des données dans un objet consiste à s'assurer que l'objet
est dans un état valide quand il est créé. Pour faire cela, vous pouvez définir un
initialisateur. Si votre classe a une méthode nommée `init()`, elle est appelée
automatiquement quand l'objet est construit. Tous les paramètres passés à la classe
sont transmis à son initialisateur.

```lox
class Breakfast {
  init(meat, bread) {
    this.meat = meat;
    this.bread = bread;
  }

  // ...
}

var baconAndToast = Breakfast("bacon", "toast");
baconAndToast.serve("Dear Reader");
// "Enjoy your bacon and toast, Dear Reader."
```

### Héritage

Chaque langage orienté objet vous permet non seulement de définir des méthodes, mais
de les réutiliser à travers plusieurs classes ou objets. Pour cela, Lox supporte
l'héritage simple. Quand vous déclarez une classe, vous pouvez spécifier une classe
dont elle hérite en utilisant un opérateur inférieur à <span name="less">(`<`)</span>.

```lox
class Brunch < Breakfast {
  drink() {
    print "How about a Bloody Mary?";
  }
}
```

<aside name="less">

Pourquoi l'opérateur `<` ? Je n'avais pas envie d'introduire un nouveau mot-clé comme
`extends`. Lox n'utilise pas `:` pour quoi que ce soit d'autre donc je ne voulais
pas réserver cela non plus. Au lieu de cela, j'ai pris une page de Ruby et utilisé `<`.

Si vous connaissez un peu de théorie des types, vous remarquerez que ce n'est pas un
choix *totalement* arbitraire. Chaque instance d'une sous-classe est aussi une instance
de sa superclasse, mais il peut y avoir des instances de la superclasse qui ne sont
pas des instances de la sous-classe. Cela signifie, dans l'univers des objets, que
l'ensemble des objets de la sous-classe est plus petit que l'ensemble de la superclasse,
bien que les nerds de la théorie des types utilisent habituellement `<:` pour cette
relation.

</aside>

Ici, Brunch est la **classe dérivée** ou **sous-classe**, et Breakfast est la
**classe de base** ou **superclasse**.

Chaque méthode définie dans la superclasse est aussi disponible pour ses sous-classes.

```lox
var benedict = Brunch("ham", "English muffin");
benedict.serve("Noble Reader");
```

Même la méthode `init()` est <span name="init">héritée</span>. En pratique,
la sous-classe veut habituellement définir sa propre méthode `init()` aussi. Mais
l'originale doit aussi être appelée pour que la superclasse puisse maintenir son
état. Nous avons besoin d'un moyen d'appeler une méthode sur notre propre *instance*
sans toucher nos propres *méthodes*.

<aside name="init">

Lox est différent de C++, Java, et C#, qui n'héritent pas des constructeurs, mais
similaire à Smalltalk et Ruby, qui le font.

</aside>

Comme en Java, vous utilisez `super` pour cela.

```lox
class Brunch < Breakfast {
  init(meat, bread, drink) {
    super.init(meat, bread);
    this.drink = drink;
  }
}
```

C'est à peu près tout pour l'orientation objet. J'ai essayé de garder l'ensemble des
fonctionnalités minimal. La structure du livre a forcé un compromis. Lox n'est pas un
langage orienté objet *pur*. Dans un vrai langage POO, chaque objet est une instance
d'une classe, même les valeurs primitives comme les nombres et les Booléens.

Parce que nous n'implémentons pas les classes jusqu'à bien après avoir commencé à
travailler avec les types intégrés, cela aurait été difficile. Donc les valeurs des
types primitifs ne sont pas de vrais objets au sens d'être des instances de classes.
Elles n'ont pas de méthodes ou de propriétés. Si j'essayais de faire de Lox un vrai
langage pour de vrais utilisateurs, je corrigerais cela.

## La Bibliothèque Standard

Nous avons presque terminé. C'est tout le langage, donc tout ce qui reste est la
bibliothèque "noyau" ou "standard" -- l'ensemble de fonctionnalités qui est
implémenté directement dans l'interpréteur et sur lequel tout le comportement
défini par l'utilisateur est construit.

C'est la partie la plus triste de Lox. Sa bibliothèque standard va au-delà du
minimalisme et penche près du nihilisme pur. Pour le code d'exemple dans le livre,
nous avons seulement besoin de démontrer que le code fonctionne et fait ce qu'il
est censé faire. Pour cela, nous avons déjà l'instruction `print` intégrée.

Plus tard, quand nous commencerons à optimiser, nous écrirons quelques benchmarks
et verrons combien de temps il faut pour exécuter le code. Cela signifie que nous
avons besoin de suivre le temps, donc nous définirons une fonction intégrée,
`clock()`, qui retourne le nombre de secondes depuis que le programme a commencé.

Et... c'est tout. Je sais, n'est-ce pas ? C'est embarrassant.

Si vous vouliez transformer Lox en un langage réellement utile, la toute première
chose que vous devriez faire est étoffer cela. Manipulation de chaînes, fonctions
trigonométriques, I/O de fichiers, réseau, bon sang, même *lire l'entrée de
l'utilisateur* aiderait. Mais nous n'avons besoin de rien de tout cela pour ce
livre, et l'ajouter ne vous apprendrait rien d'intéressant, donc je l'ai laissé
de côté.

Ne vous inquiétez pas, nous aurons plein de trucs excitants dans le langage
lui-même pour nous occuper.

<div class="challenges">

## Défis

1. Écrivez quelques programmes Lox d'exemple et exécutez-les (vous pouvez utiliser
  les implémentations de Lox dans [mon dépôt][repo]). Essayez de trouver des
  comportements de cas limites que je n'ai pas spécifiés ici. Est-ce que cela
  fait ce que vous attendez ? Pourquoi ou pourquoi pas ?

2. Cette introduction informelle laisse *beaucoup* de choses non spécifiées.
  Listez plusieurs questions ouvertes que vous avez sur la syntaxe et la
  sémantique du langage. Que pensez-vous que les réponses devraient être ?

3. Lox est un langage assez petit. Quelles fonctionnalités pensez-vous qu'il
  manque qui rendraient son utilisation ennuyeuse pour de vrais programmes ?
  (Mis à part la bibliothèque standard, bien sûr.)

</div>

<div class="design-note">

## Note de Conception : Expressions et Instructions

Lox a à la fois des expressions et des instructions. Certains langages omettent
ces dernières. Au lieu de cela, ils traitent les déclarations et les constructions
de flux de contrôle comme des expressions aussi. Ces langages "tout est une
expression" tendent à avoir des pedigrees fonctionnels et incluent la plupart des
Lisps, SML, Haskell, Ruby, et CoffeeScript.

Pour faire cela, pour chaque construction "ressemblant à une instruction" dans le
langage, vous devez décider à quelle valeur elle s'évalue. Certaines d'entre elles
sont faciles :

*   Une expression `if` s'évalue au résultat de quelque branche soit choisie.
   De même, un `switch` ou autre branche multi-voies s'évalue à quelque cas
   soit choisi.

*   Une déclaration de variable s'évalue à la valeur de la variable.

*   Un bloc s'évalue au résultat de la dernière expression dans la séquence.

Certaines deviennent un peu plus étranges. À quoi une boucle devrait-elle s'évaluer ?
Une boucle `while` dans CoffeeScript s'évalue à un tableau contenant chaque élément
auquel le corps s'est évalué. Cela peut être pratique, ou un gaspillage de mémoire
si vous n'avez pas besoin du tableau.

Vous devez aussi décider comment ces expressions ressemblant à des instructions se
composent avec d'autres expressions -- vous devez les adapter dans la table de
précédence de la grammaire. Par exemple, Ruby permet :

```ruby
puts 1 + if true then 2 else 3 end + 4
```

Est-ce que c'est ce que vous attendriez ? Est-ce que c'est ce que vos *utilisateurs*
attendent ? Comment cela affecte-t-il la façon dont vous concevez la syntaxe pour vos
"instructions" ? Notez que Ruby a un `end` explicite pour dire quand l'expression `if`
est complète. Sans cela, le `+ 4` serait probablement analysé comme partie de la
clause `else`.

Transformer chaque instruction en expression vous force à répondre à quelques questions
épineuses comme cela. En retour, vous éliminez une certaine redondance. C a à la fois
des blocs pour séquencer les instructions, et l'opérateur virgule pour séquencer les
expressions. Il a à la fois l'instruction `if` et l'opérateur conditionnel `?:`. Si
tout était une expression en C, vous pourriez unifier chacun d'entre eux.

Les langages qui se débarrassent des instructions ont aussi habituellement des
**retours implicites** -- une fonction retourne automatiquement quelle que soit la
valeur à laquelle son corps s'évalue sans besoin d'une syntaxe `return` explicite.
Pour les petites fonctions et méthodes, c'est vraiment pratique. En fait, beaucoup
de langages qui ont des instructions ont ajouté une syntaxe comme `=>` pour pouvoir
définir des fonctions dont le corps est le résultat de l'évaluation d'une seule
expression.

Mais faire fonctionner *toutes* les fonctions de cette façon peut être un peu étrange.
Si vous n'êtes pas prudent, votre fonction va laisser fuir une valeur de retour même
si vous n'avez l'intention que de produire un effet de bord. En pratique, cependant,
les utilisateurs de ces langages ne trouvent pas que c'est un problème.

Pour Lox, je lui ai donné des instructions pour des raisons prosaïques. J'ai choisi
une syntaxe ressemblant à C par souci de familiarité, et essayer de prendre la
syntaxe d'instruction C existante et l'interpréter comme des expressions devient
bizarre assez rapidement.

</div>
