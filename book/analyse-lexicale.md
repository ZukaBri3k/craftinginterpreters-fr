> Voyez grand. Tout ce qui mérite d'être fait mérite d'être fait avec excès.
>
> <cite>Robert A. Heinlein, <em>Time Enough for Love</em></cite>

La première étape de tout compilateur ou interpréteur est l'<span
name="lexing">analyse lexicale</span> (scanning). Le scanner prend le code source brut sous forme d'une série de caractères et le regroupe en une série de blocs que nous appelons **tokens**. Ce sont les "mots" et la "ponctuation" significatifs qui constituent la grammaire du langage.

<aside name="lexing">

Cette tâche a été appelée diversement "scanning" et "lexing" (abréviation de "analyse lexicale") au fil des ans. À l'époque où les ordinateurs étaient aussi gros que des camping-cars mais avaient moins de mémoire que votre montre, certains utilisaient "scanner" uniquement pour désigner le morceau de code qui s'occupait de lire les caractères du code source brut depuis le disque et de les mettre en mémoire tampon. Ensuite, le "lexing" était la phase suivante qui faisait des choses utiles avec les caractères.

De nos jours, lire un fichier source en mémoire est trivial, c'est donc rarement une phase distincte dans le compilateur. De ce fait, les deux termes sont fondamentalement interchangeables.

</aside>

L'analyse lexicale est aussi un bon point de départ pour nous car le code n'est pas très difficile -- c'est à peu près une instruction `switch` avec la folie des grandeurs. Cela nous aidera à nous échauffer avant d'aborder des sujets plus intéressants plus tard. À la fin de ce chapitre, nous aurons un scanner complet et rapide qui pourra prendre n'importe quelle chaîne de code source Lox et produire les tokens que nous fournirons au parseur dans le chapitre suivant.

## Le cadre de l'interpréteur

Puisque c'est notre premier vrai chapitre, avant de commencer à scanner du code, nous devons esquisser la forme de base de notre interpréteur, jlox. Tout commence par une classe en Java.

^code lox-class

<aside name="64">

Pour les codes de sortie, j'utilise les conventions définies dans l'en-tête UNIX ["sysexits.h"][sysexits]. C'est la chose la plus proche d'un standard que j'ai pu trouver.

[sysexits]: https://www.freebsd.org/cgi/man.cgi?query=sysexits&apropos=0&sektion=0&manpath=FreeBSD+4.3-RELEASE&format=html

</aside>

Mettez cela dans un fichier texte, et préparez votre IDE ou Makefile ou quoi que ce soit. Je serai juste là quand vous serez prêt. C'est bon ? OK !

Lox est un langage de script, ce qui signifie qu'il s'exécute directement à partir du code source. Notre interpréteur supporte deux façons d'exécuter du code. Si vous lancez jlox depuis la ligne de commande et lui donnez un chemin vers un fichier, il lit le fichier et l'exécute.

^code run-file

Si vous voulez une conversation plus intime avec votre interpréteur, vous pouvez aussi l'exécuter de manière interactive. Lancez jlox sans aucun argument, et il vous dépose dans une invite où vous pouvez entrer et exécuter du code une ligne à la fois.

<aside name="repl">

Une invite interactive est aussi appelée un "REPL" (prononcé comme "rebel" mais avec un "p"). Le nom vient de Lisp où en implémenter un est aussi simple que d'envelopper une boucle autour de quelques fonctions intégrées :

```lisp
(print (eval (read)))
```

En partant de l'appel le plus imbriqué vers l'extérieur, vous lisez (**R**ead) une ligne d'entrée, l'évaluez (**E**valuate), affichez (**P**rint) le résultat, puis bouclez (**L**oop) pour recommencer.

</aside>

^code prompt

La fonction `readLine()`, comme son nom l'indique si utilement, lit une ligne d'entrée de l'utilisateur sur la ligne de commande et renvoie le résultat. Pour tuer une application interactive en ligne de commande, vous tapez généralement Contrôle-D. Cela signale une condition "fin de fichier" au programme. Lorsque cela se produit, `readLine()` renvoie `null`, donc nous vérifions cela pour quitter la boucle.

L'invite et le lanceur de fichier sont tous deux de minces enveloppes autour de cette fonction centrale :

^code run

Ce n'est pas encore très utile puisque nous n'avons pas écrit l'interpréteur, mais piano piano, n'est-ce pas ? Pour l'instant, cela affiche les tokens que notre futur scanner émettra afin que nous puissions voir si nous progressons.

### Gestion des erreurs

Pendant que nous mettons les choses en place, une autre pièce clé de l'infrastructure est la _gestion des erreurs_. Les manuels scolaires passent parfois cela sous silence car c'est plus une question pratique qu'un problème formel d'informatique. Mais si vous vous souciez de faire un langage réellement _utilisable_, alors gérer les erreurs avec grâce est vital.

Les outils que notre langage fournit pour gérer les erreurs constituent une grande partie de son interface utilisateur. Lorsque le code de l'utilisateur fonctionne, il ne pense pas du tout à notre langage -- son esprit est tout entier à _son programme_. C'est généralement seulement quand les choses tournent mal qu'ils remarquent notre implémentation.

<span name="errors">Lorsque</span> cela arrive, c'est à nous de donner à l'utilisateur toutes les informations dont il a besoin pour comprendre ce qui a mal tourné et le guider doucement vers là où il essaie d'aller. Bien faire cela signifie penser à la gestion des erreurs tout au long de l'implémentation de notre interpréteur, en commençant maintenant.

<aside name="errors">

Ceci étant dit, pour _cet_ interpréteur, ce que nous allons construire est assez minimaliste. J'adorerais parler de débogueurs interactifs, d'analyseurs statiques et d'autres choses amusantes, mais il n'y a pas tant d'encre que ça dans le stylo.

</aside>

^code lox-error

Cette fonction `error()` et son aide `report()` indiquent à l'utilisateur qu'une erreur de syntaxe s'est produite sur une ligne donnée. C'est vraiment le strict minimum pour pouvoir prétendre que vous _avez_ même un rapport d'erreurs. Imaginez si vous laissiez accidentellement une virgule pendante dans un appel de fonction et que l'interpréteur affichait :

```text
Error: Unexpected "," somewhere in your code. Good luck finding it!
```

Ce n'est pas très utile. Nous devons au moins les diriger vers la bonne ligne. Encore mieux serait la colonne de début et de fin pour qu'ils sachent _où_ dans la ligne. Encore mieux que _ça_ serait de _montrer_ à l'utilisateur la ligne incriminée, comme :

```text
Error: Unexpected "," in argument list.

    15 | function(first, second,);
                               ^-- Here.
```

J'adorerais implémenter quelque chose comme ça dans ce livre, mais la vérité honnête est que c'est beaucoup de code de manipulation de chaînes fastidieux. Très utile pour les utilisateurs, mais pas super amusant à lire dans un livre et pas très intéressant techniquement. Donc nous nous en tiendrons juste à un numéro de ligne. Dans vos propres interpréteurs, faites ce que je dis et non ce que je fais.

La raison principale pour laquelle nous mettons cette fonction de rapport d'erreur dans la classe principale Lox est à cause de ce champ `hadError`. Il est défini ici :

^code had-error (1 before)

Nous utiliserons cela pour nous assurer que nous n'essayons pas d'exécuter du code qui a une erreur connue. Aussi, cela nous permet de quitter avec un code de sortie non nul comme un bon citoyen de la ligne de commande devrait le faire.

^code exit-code (1 before, 1 after)

Nous devons réinitialiser ce drapeau dans la boucle interactive. Si l'utilisateur fait une erreur, cela ne devrait pas tuer toute sa session.

^code reset-had-error (1 before, 1 after)

L'autre raison pour laquelle j'ai sorti le rapport d'erreur ici au lieu de le fourrer dans le scanner et d'autres phases où l'erreur pourrait se produire est pour vous rappeler que c'est une bonne pratique d'ingénierie de séparer le code qui _génère_ les erreurs du code qui les _rapporte_.

Diverses phases du front-end détecteront des erreurs, mais ce n'est pas vraiment leur travail de savoir comment présenter cela à un utilisateur. Dans une implémentation de langage complète, vous aurez probablement plusieurs façons d'afficher les erreurs : sur stderr, dans la fenêtre d'erreur d'un IDE, consigné dans un fichier, etc. Vous ne voulez pas que ce code soit étalé partout dans votre scanner et votre parseur.

Idéalement, nous aurions une véritable abstraction, une sorte d'interface <span name="reporter">"ErrorReporter"</span> qui serait passée au scanner et au parseur afin que nous puissions échanger différentes stratégies de rapport. Pour notre interpréteur simple ici, je n'ai pas fait cela, mais j'ai au moins déplacé le code de rapport d'erreur dans une classe différente.

<aside name="reporter">

J'avais exactement cela quand j'ai implémenté jlox pour la première fois. J'ai fini par l'enlever parce que cela semblait sur-ingénierie pour l'interpréteur minimal de ce livre.

</aside>

Avec une gestion rudimentaire des erreurs en place, notre coquille d'application est prête. Une fois que nous aurons une classe Scanner avec une méthode `scanTokens()`, nous pourrons commencer à l'exécuter. Avant d'en arriver là, soyons plus précis sur ce que sont les tokens.

## Lexèmes et Tokens

Voici une ligne de code Lox :

```lox
var language = "lox";
```

Ici, `var` est le mot-clé pour déclarer une variable. Cette séquence de trois caractères "v-a-r" signifie quelque chose. Mais si nous arrachons trois lettres au milieu de `language`, comme "g-u-a", celles-ci ne signifient rien par elles-mêmes.

C'est de cela qu'il s'agit dans l'analyse lexicale. Notre travail est de parcourir la liste des caractères et de les regrouper dans les plus petites séquences qui représentent encore quelque chose. Chacun de ces blocs de caractères est appelé un **lexème**. Dans cet exemple de ligne de code, les lexèmes sont :

<img src="image/scanning/lexemes.png" alt="'var', 'language', '=', 'lox', ';'" />

Les lexèmes ne sont que les sous-chaînes brutes du code source. Cependant, dans le processus de regroupement des séquences de caractères en lexèmes, nous tombons également sur d'autres informations utiles. Lorsque nous prenons le lexème et le regroupons avec ces autres données, le résultat est un token. Il comprend des choses utiles comme :

### Type de token

Les mots-clés font partie de la forme de la grammaire du langage, donc le parseur a souvent du code comme, "Si le prochain token est `while` alors faire...". Cela signifie que le parseur veut savoir non seulement qu'il a un lexème pour un identifiant, mais qu'il a un mot _réservé_, et _quel_ mot-clé c'est.

Le <span name="ugly">parseur</span> pourrait catégoriser les tokens à partir du lexème brut en comparant les chaînes, mais c'est lent et un peu laid. Au lieu de cela, au moment où nous reconnaissons un lexème, nous nous souvenons aussi de quel _genre_ de lexème il représente. Nous avons un type différent pour chaque mot-clé, opérateur, morceau de ponctuation et type littéral.

<aside name="ugly">

Après tout, la comparaison de chaînes finit par regarder les caractères individuels, et n'est-ce pas le travail du scanner ?

</aside>

^code token-type

### Valeur littérale

Il y a des lexèmes pour les valeurs littérales -- nombres et chaînes et autres. Puisque le scanner doit parcourir chaque caractère du littéral pour l'identifier correctement, il peut aussi convertir cette représentation textuelle d'une valeur en l'objet vivant à l'exécution qui sera utilisé par l'interpréteur plus tard.

### Informations de localisation

Quand je prêchais l'évangile sur la gestion des erreurs, nous avons vu que nous devons dire aux utilisateurs _où_ les erreurs se sont produites. Le suivi de cela commence ici. Dans notre interpréteur simple, nous notons seulement sur quelle ligne le token apparaît, mais des implémentations plus sophistiquées incluent aussi la colonne et la longueur.

<aside name="location">

Certaines implémentations de tokens stockent la localisation sous forme de deux nombres : le décalage depuis le début du fichier source jusqu'au début du lexème, et la longueur du lexème. Le scanner a besoin de les connaître de toute façon, donc il n'y a pas de surcharge à les calculer.

Un décalage peut être converti en positions de ligne et de colonne plus tard en regardant en arrière dans le fichier source et en comptant les retours à la ligne précédents. Cela semble lent, et ça l'est. Cependant, vous n'avez besoin de le faire _que lorsque vous devez réellement afficher une ligne et une colonne à l'utilisateur_. La plupart des tokens n'apparaissent jamais dans un message d'erreur. Pour ceux-là, moins vous passez de temps à calculer les informations de position à l'avance, mieux c'est.

</aside>

Nous prenons toutes ces données et les enveloppons dans une classe.

^code token-class

Maintenant nous avons un objet avec assez de structure pour être utile pour toutes les phases ultérieures de l'interpréteur.

## Langages Réguliers et Expressions

Maintenant que nous savons ce que nous essayons de produire, eh bien, produisons-le. Le cœur du scanner est une boucle. En commençant au premier caractère du code source, le scanner détermine à quel lexème le caractère appartient, et le consomme ainsi que tous les caractères suivants qui font partie de ce lexème. Lorsqu'il atteint la fin de ce lexème, il émet un token.

Puis il boucle en arrière et recommence, en commençant par le caractère tout juste suivant dans le code source. Il continue à faire cela, mangeant des caractères et occasionnellement, euh, excrétant des tokens, jusqu'à ce qu'il atteigne la fin de l'entrée.

<span name="alligator"></span>

<img src="image/scanning/lexigator.png" alt="Un alligator mangeant des caractères et, eh bien, vous ne voulez pas savoir." />

<aside name="alligator">

Lexical analygator. (Jeu de mots intraduisible sur Analysis/Alligator)

</aside>

La partie de la boucle où nous regardons une poignée de caractères pour comprendre quel genre de lexème cela "matche" peut sembler familière. Si vous connaissez les expressions régulières, vous pourriez envisager de définir une regex pour chaque genre de lexème et de les utiliser pour matcher les caractères. Par exemple, Lox a les mêmes règles que C pour les identifiants (noms de variables et autres). Cette regex en matche une :

```text
[a-zA-Z_][a-zA-Z_0-9]*
```

Si vous avez pensé aux expressions régulières, votre intuition est profonde. Les règles qui déterminent comment un langage particulier regroupe les caractères en lexèmes sont appelées sa <span name="theory">**grammaire lexicale**</span>. Dans Lox, comme dans la plupart des langages de programmation, les règles de cette grammaire sont assez simples pour que le langage soit classé comme un **[langage régulier][]**. C'est le même "régulier" que dans les expressions régulières.

[regular language]: https://en.wikipedia.org/wiki/Regular_language

<aside name="theory">

Cela me peine de passer autant sous silence la théorie, surtout quand elle est aussi intéressante que je pense que le sont la [hiérarchie de Chomsky][] et les [machines à états finis][]. Mais la vérité honnête est que d'autres livres couvrent cela mieux que je ne le pourrais. [_Compilers: Principles, Techniques, and Tools_][dragon] (universellement connu comme "le dragon book") est la référence canonique.

[chomsky hierarchy]: https://en.wikipedia.org/wiki/Chomsky_hierarchy
[dragon]: https://en.wikipedia.org/wiki/Compilers:_Principles,_Techniques,_and_Tools
[finite-state machines]: https://en.wikipedia.org/wiki/Finite-state_machine

</aside>

Vous pouvez très précisément reconnaître tous les différents lexèmes pour Lox en utilisant des regexes si vous le voulez, et il y a une pile de théorie intéressante sous-jacente sur pourquoi c'est ainsi et ce que cela signifie. Des outils comme [Lex][] ou [Flex][] sont conçus expressément pour vous permettre de faire cela -- jetez-leur une poignée de regexes, et ils vous donnent un scanner complet en <span name="lex">retour</span>.

<aside name="lex">

Lex a été créé par Mike Lesk et Eric Schmidt. Oui, le même Eric Schmidt qui fut président exécutif de Google. Je ne dis pas que les langages de programmation sont un chemin infaillible vers la richesse et la gloire, mais nous _pouvons_ compter au moins un mégamilliardaire parmi nous.

</aside>

[lex]: http://dinosaur.compilertools.net/lex/
[flex]: https://github.com/westes/flex

Puisque notre but est de comprendre comment un scanner fait ce qu'il fait, nous ne déléguerons pas cette tâche. Nous sommes pour les produits faits main.

## La Classe Scanner

Sans plus tarder, faisons-nous un scanner.

^code scanner-class

<aside name="static-import">

Je sais que les imports statiques sont considérés comme du mauvais style par certains, mais ils m'évitent d'avoir à saupoudrer `TokenType.` partout dans le scanner et le parseur. Pardonnez-moi, mais chaque caractère compte dans un livre.

</aside>

Nous stockons le code source brut comme une simple chaîne, et nous avons une liste prête à être remplie avec les tokens que nous allons générer. La boucle susmentionnée qui fait cela ressemble à ceci :

^code scan-tokens

Le scanner avance à travers le code source, ajoutant des tokens jusqu'à ce qu'il n'y ait plus de caractères. Ensuite, il ajoute un token final "fin de fichier". Ce n'est pas strictement nécessaire, mais cela rend notre parseur un peu plus propre.

Cette boucle dépend de quelques champs pour garder une trace d'où se trouve le scanner dans le code source.

^code scan-state (1 before, 2 after)

Les champs `start` et `current` sont des décalages qui indexent dans la chaîne. Le champ `start` pointe vers le premier caractère du lexème en cours de scan, et `current` pointe vers le caractère actuellement considéré. Le champ `line` suit sur quelle ligne source se trouve `current` afin que nous puissions produire des tokens qui connaissent leur emplacement.

Ensuite, nous avons une petite fonction d'aide qui nous dit si nous avons consommé tous les caractères.

^code is-at-end

## Reconnaître les Lexèmes

À chaque tour de boucle, nous scannons un seul token. C'est le vrai cœur du scanner. Nous commencerons simplement. Imaginez si chaque lexème ne faisait qu'un seul caractère de long. Tout ce que vous auriez à faire serait de consommer le caractère suivant et de choisir un type de token pour lui. Plusieurs lexèmes _sont_ de fait d'un seul caractère en Lox, donc commençons par ceux-là.

^code scan-token

<aside name="slash">

Vous vous demandez pourquoi `/` n'est pas là-dedans ? Ne vous inquiétez pas, nous y viendrons.

</aside>

Encore une fois, nous avons besoin de quelques méthodes d'aide.

^code advance-and-add-token

La méthode `advance()` consomme le caractère suivant dans le fichier source et le renvoie. Là où `advance()` est pour l'entrée, `addToken()` est pour la sortie. Elle saisit le texte du lexème courant et crée un nouveau token pour lui. Nous utiliserons l'autre surcharge pour gérer les tokens avec des valeurs littérales bientôt.

### Erreurs lexicales

Avant d'aller trop loin, prenons un moment pour penser aux erreurs au niveau lexical. Que se passe-t-il si un utilisateur jette un fichier source contenant des caractères que Lox n'utilise pas, comme `@#^`, à notre interpréteur ? Pour l'instant, ces caractères sont silencieusement ignorés. Ils ne sont pas utilisés par le langage Lox, mais cela ne signifie pas que l'interpréteur peut prétendre qu'ils ne sont pas là. Au lieu de cela, nous rapportons une erreur.

^code char-error (1 before, 1 after)

Notez que le caractère erroné est quand même _consommé_ par l'appel précédent à `advance()`. C'est important pour que nous ne restions pas coincés dans une boucle infinie.

Notez aussi que nous <span name="shotgun">_continuons à scanner_</span>. Il peut y avoir d'autres erreurs plus loin dans le programme. Cela donne à nos utilisateurs une meilleure expérience si nous en détectons autant que possible en une seule fois. Sinon, ils voient une petite erreur et la corrigent, seulement pour voir l'erreur suivante apparaître, et ainsi de suite. Le jeu de la taupe des erreurs de syntaxe n'est pas amusant.

(Ne vous inquiétez pas. Puisque `hadError` est défini, nous n'essaierons jamais d'_exécuter_ le moindre code, même si nous continuons et scannons le reste.)

<aside name="shotgun">

Le code rapporte chaque caractère invalide séparément, donc cela bombarde l'utilisateur d'une rafale d'erreurs s'ils collent accidentellement un gros pâté de texte bizarre. Regrouper une suite de caractères invalides en une seule erreur donnerait une expérience utilisateur plus agréable.

</aside>

### Opérateurs

Nous avons les lexèmes à caractère unique qui fonctionnent, mais cela ne couvre pas tous les opérateurs de Lox. Quid de `!` ? C'est un seul caractère, non ? Parfois, oui, mais si le caractère juste après est un signe égal, alors nous devrions à la place créer un lexème `!=`. Notez que le `!` et le `=` ne sont _pas_ deux opérateurs indépendants. Vous ne pouvez pas écrire `!   =` en Lox et avoir le comportement d'un opérateur d'inégalité. C'est pourquoi nous devons scanner `!=` comme un seul lexème. De même, `<`, `>`, et `=` peuvent tous être suivis par `=` pour créer les autres opérateurs d'égalité et de comparaison.

Pour tous ceux-ci, nous devons regarder le second caractère.

^code two-char-tokens (1 before, 2 after)

Ces cas utilisent cette nouvelle méthode :

^code match

C'est comme un `advance()` conditionnel. Nous ne consommons le caractère actuel que s'il correspond à ce que nous cherchons.

En utilisant `match()`, nous reconnaissons ces lexèmes en deux étapes. Lorsque nous atteignons, par exemple, `!`, nous sautons à son cas dans le switch. Cela signifie que nous savons que le lexème _commence_ par `!`. Ensuite, nous regardons le caractère suivant pour déterminer si nous sommes sur un `!=` ou simplement un `!`.

## Lexèmes plus longs

Il nous manque encore un opérateur : `/` pour la division. Ce caractère nécessite un traitement un peu spécial car les commentaires commencent aussi par une barre oblique.

^code slash (1 before, 2 after)

C'est similaire aux autres opérateurs à deux caractères, sauf que lorsque nous trouvons un second `/`, nous ne terminons pas encore le token. Au lieu de cela, nous continuons à consommer des caractères jusqu'à ce nous atteignions la fin de la ligne.

C'est notre stratégie générale pour gérer les lexèmes plus longs. Après avoir détecté le début de l'un d'eux, nous basculons vers un code spécifique au lexème qui continue à manger des caractères jusqu'à ce qu'il voie la fin.

Nous avons un autre assistant :

^code peek

C'est un peu comme `advance()`, mais ne consomme pas le caractère. Cela s'appelle <span name="match">**lookahead**</span> (lecture anticipée). Puisqu'il ne regarde que le caractère actuel non consommé, nous avons _un caractère d'anticipation_. Plus ce nombre est petit, généralement, plus le scanner s'exécute vite. Les règles de la grammaire lexicale dictent combien d'anticipation nous avons besoin. Heureusement, la plupart des langages largement utilisés ne regardent qu'un ou deux caractères en avance.

<aside name="match">

Techniquement, `match()` fait aussi de l'anticipation. `advance()` et `peek()` sont les opérateurs fondamentaux et `match()` les combine.

</aside>

Les commentaires sont des lexèmes, mais ils ne sont pas significatifs, et le parseur ne veut pas avoir à faire avec eux. Donc, lorsque nous atteignons la fin du commentaire, nous _n'appelons pas_ `addToken()`. Lorsque nous bouclons pour commencer le prochain lexème, `start` est réinitialisé et le lexème du commentaire disparaît dans un nuage de fumée.

Pendant que nous y sommes, c'est le bon moment pour sauter ces autres caractères sans signification : les retours à la ligne et les espaces.

^code whitespace (1 before, 3 after)

Lorsque nous rencontrons un espace, nous retournons simplement au début de la boucle de scan. Cela commence un nouveau lexème _après_ le caractère d'espace. Pour les retours à la ligne, nous faisons la même chose, mais nous incrémentons aussi le compteur de ligne. (C'est pourquoi nous avons utilisé `peek()` pour trouver le retour à la ligne terminant un commentaire au lieu de `match()`. Nous voulons que ce retour à la ligne nous amène ici pour pouvoir mettre à jour `line`.)

Notre scanner devient plus intelligent. Il peut gérer du code assez libre comme :

```lox
// ceci est un commentaire
(( )){} // des trucs de groupement
!*+-/=<> <= == // opérateurs
```

### Littéraux de chaîne

Maintenant que nous sommes à l'aise avec les lexèmes plus longs, nous sommes prêts à nous attaquer aux littéraux. Nous ferons les chaînes en premier, puisqu'elles commencent toujours par un caractère spécifique, `"`.

^code string-start (1 before, 2 after)

Cela appelle :

^code string

Comme avec les commentaires, nous consommons des caractères jusqu'à ce que nous touchions le `"` qui termine la chaîne. Nous gérons aussi gracieusement le cas où nous manquons d'entrée avant que la chaîne ne soit fermée et rapportons une erreur pour cela.

Sans raison particulière, Lox supporte les chaînes multi-lignes. Il y a des pour et des contre à cela, mais les interdire était un peu plus complexe que de les permettre, donc je les ai laissées. Cela signifie que nous devons aussi mettre à jour `line` quand nous rencontrons un retour à la ligne à l'intérieur d'une chaîne.

Enfin, le dernier morceau intéressant est que lorsque nous créons le token, nous produisons aussi la _valeur_ réelle de la chaîne qui sera utilisée plus tard par l'interpréteur. Ici, cette conversion nécessite seulement un `substring()` pour enlever les guillemets environnants. Si Lox supportait les séquences d'échappement comme `\n`, nous les déséchapperions ici.

### Littéraux numériques

Tous les nombres dans Lox sont à virgule flottante à l'exécution, mais les littéraux entiers et décimaux sont tous deux supportés. Un littéral numérique est une série de <span name="minus">chiffres</span> optionnellement suivie par un `.` et un ou plusieurs chiffres suivants.

<aside name="minus">

Puisque nous ne cherchons qu'un chiffre pour commencer un nombre, cela signifie que `-123` n'est pas un _littéral_ numérique. Au lieu de cela, `-123` est une _expression_ qui applique `-` au littéral numérique `123`. En pratique, le résultat est le même, bien qu'il y ait un cas limite intéressant si nous devions ajouter des appels de méthode sur les nombres. Considérez :

```lox
print -123.abs();
```

Ceci affiche `-123` parce que la négation a une précédence plus basse que les appels de méthode. Nous pourrions corriger cela en faisant de `-` une partie du littéral numérique. Mais considérez alors :

```lox
var n = 123;
print -n.abs();
```

Cela produit toujours `-123`, donc maintenant le langage semble incohérent. Quoi que vous fassiez, certains cas finissent par être bizarres.

</aside>

```lox
1234
12.34
```

Nous n'autorisons pas de point décimal initial ou final, donc ceux-ci sont tous deux invalides :

```lox
.1234
1234.
```

Nous pourrions facilement supporter le premier, mais je l'ai laissé de côté pour garder les choses simples. Le second devient bizarre si jamais nous voulons permettre des méthodes sur les nombres comme `123.sqrt()`.

Pour reconnaître le début d'un lexème numérique, nous cherchons n'importe quel chiffre. C'est un peu fastidieux d'ajouter des cas pour chaque chiffre décimal, donc nous le fourrons dans le cas par défaut à la place.

^code digit-start (1 before, 1 after)

Cela repose sur ce petit utilitaire :

^code is-digit

<aside name="is-digit">

La bibliothèque standard Java fournit [`Character.isDigit()`][is-digit], qui semble être un bon choix. Hélas, cette méthode autorise des choses comme les chiffres Devanagari, les nombres pleine chasse, et d'autres trucs drôles dont nous ne voulons pas.

[is-digit]: http://docs.oracle.com/javase/7/docs/api/java/lang/Character.html#isDigit(char)

</aside>

Une fois que nous savons que nous sommes dans un nombre, nous bifurquons vers une méthode séparée pour consommer le reste du littéral, comme nous le faisons avec les chaînes.

^code number

Nous consommons autant de chiffres que nous trouvons pour la partie entière du littéral. Ensuite nous cherchons une partie fractionnaire, qui est un point décimal (`.`) suivi d'au moins un chiffre. Si nous avons une partie fractionnaire, encore une fois, nous consommons autant de chiffres que nous pouvons trouver.

Regarder au-delà du point décimal nécessite un deuxième caractère d'anticipation puisque nous ne voulons pas consommer le `.` tant que nous ne sommes pas sûrs qu'il y a un chiffre _après_ lui. Donc nous ajoutons :

^code peek-next

<aside name="peek-next">

J'aurais pu faire en sorte que `peek()` prenne un paramètre pour le nombre de caractères à regarder en avant au lieu de définir deux fonctions, mais cela permettrait une anticipation _arbitrairement_ lointaine. Fournir ces deux fonctions rend plus clair pour un lecteur du code que notre scanner regarde en avant au plus deux caractères.

</aside>

Enfin, nous convertissons le lexème en sa valeur numérique. Notre interpréteur utilise le type Java `Double` pour représenter les nombres, donc nous produisons une valeur de ce type. Nous utilisons la propre méthode de parsing de Java pour convertir le lexème en un vrai double Java. Nous pourrions implémenter cela nous-mêmes, mais, honnêtement, à moins que vous n'essayiez de réviser pour un entretien de programmation imminent, cela ne vaut pas votre temps.

Les littéraux restants sont les Booléens et `nil`, mais nous les gérons comme des mots-clés, ce qui nous amène à...

## Mots Réservés et Identifiants

Notre scanner est presque terminé. Les seules pièces restantes de la grammaire lexicale à implémenter sont les identifiants et leurs proches cousins, les mots réservés. Vous pourriez penser que nous pourrions matcher les mots-clés comme `or` de la même manière que nous gérons les opérateurs à plusieurs caractères comme `<=`.

```java
case 'o':
  if (match('r')) {
    addToken(OR);
  }
  break;
```

Considérez ce qui se passerait si un utilisateur nommait une variable `orchid`. Le scanner verrait les deux premières lettres, `or`, et émettrait immédiatement un token mot-clé `or`. Cela nous amène à un principe important appelé <span name="maximal">**maximal munch**</span> (bouchée maximale). Lorsque deux règles de grammaire lexicale peuvent toutes deux matcher un morceau de code que le scanner regarde, _celle qui matche le plus de caractères gagne_.

Cette règle stipule que si nous pouvons matcher `orchid` comme un identifiant et `or` comme un mot-clé, alors le premier gagne. C'est aussi pourquoi nous avons tacitement supposé, précédemment, que `<=` devrait être scanné comme un seul token `<=` et non `<` suivi de `=`.

<aside name="maximal">

Considérez ce méchant morceau de code C :

```c
---a;
```

Est-ce valide ? Cela dépend de comment le scanner sépare les lexèmes. Et si le scanner le voit comme ça :

```c
- --a;
```

Alors cela pourrait être parsé. Mais cela nécessiterait que le scanner connaisse la structure grammaticale du code environnant, ce qui emmêle les choses plus que nous ne le voulons. Au lieu de cela, la règle du maximal munch dit que c'est _toujours_ scanné comme :

```c
-- -a;
```

Il le scanne de cette façon même si le faire conduit à une erreur de syntaxe plus tard dans le parseur.

</aside>

Maximal munch signifie que nous ne pouvons pas facilement détecter un mot réservé avant d'avoir atteint la fin de ce qui pourrait être à la place un identifiant. Après tout, un mot réservé _est_ un identifiant, c'est juste un qui a été réclamé par le langage pour son propre usage. C'est de là que vient le terme **mot réservé**.

Donc nous commençons par supposer que tout lexème commençant par une lettre ou un tiret bas est un identifiant.

^code identifier-start (3 before, 3 after)

Le reste du code vit par ici :

^code identifier

Nous définissons cela en termes de ces assistants :

^code is-alpha

Cela fait fonctionner les identifiants. Pour gérer les mots-clés, nous regardons si le lexème de l'identifiant est l'un des mots réservés. Si c'est le cas, nous utilisons un type de token spécifique à ce mot-clé. Nous définissons l'ensemble des mots réservés dans une map.

^code keyword-map

Puis, après avoir scanné un identifiant, nous vérifions s'il correspond à quelque chose dans la map.

^code keyword-type (2 before, 1 after)

Si oui, nous utilisons le type de token de ce mot-clé. Sinon, c'est un identifiant défini par l'utilisateur ordinaire.

Et avec cela, nous avons maintenant un scanner complet pour toute la grammaire lexicale de Lox. Lancez le REPL et tapez un peu de code valide et invalide. Est-ce qu'il produit les tokens que vous attendez ? Essayez de trouver quelques cas limites intéressants et voyez s'il les gère comme il devrait.

<div class="challenges">

## Défis

1.  Les grammaires lexicales de Python et Haskell ne sont pas _régulières_. Qu'est-ce que cela signifie, et pourquoi ne le sont-elles pas ?

1.  À part pour séparer les tokens -- distinguer `print foo` de `printfoo` -- les espaces ne sont pas beaucoup utilisés dans la plupart des langages. Cependant, dans quelques coins sombres, un espace _affecte_ comment le code est parsé en CoffeeScript, Ruby, et le préprocesseur C. Où et quel effet cela a-t-il dans chacun de ces langages ?

1.  Notre scanner ici, comme la plupart, rejette les commentaires et les espaces puisque ceux-ci ne sont pas nécessaires au parseur. Pourquoi voudriez-vous écrire un scanner qui ne les rejette _pas_ ? Pour quoi cela serait-il utile ?

1.  Ajoutez le support au scanner de Lox pour les commentaires par bloc de style C `/* ... */`. Assurez-vous de gérer les retours à la ligne dedans. Considérez de leur permettre de s'imbriquer. Est-ce qu'ajouter le support pour l'imbrication est plus de travail que vous ne l'attendiez ? Pourquoi ?

</div>

<div class="design-note">

## Note de Conception : Points-virgules Implicites

Les programmeurs d'aujourd'hui ont l'embarras du choix en matière de langages et sont devenus difficiles sur la syntaxe. Ils veulent que leur langage paraisse propre et moderne. Un bout de lichen syntaxique que presque chaque nouveau langage gratte (et que certains anciens comme BASIC n'ont jamais eu) est le `;` comme terminateur d'instruction explicite.

Au lieu de cela, ils traitent un retour à la ligne comme un terminateur d'instruction là où cela a du sens. La partie "là où cela a du sens" est le morceau difficile. Alors que la _plupart_ des instructions sont sur leur propre ligne, parfois vous avez besoin d'étaler une seule instruction sur quelques lignes. Ces retours à la ligne entremêlés ne devraient pas être traités comme des terminateurs.

La plupart des cas évidents où le retour à la ligne devrait être ignoré sont faciles à détecter, mais il y en a une poignée de méchants :

- Une valeur de retour sur la ligne suivante :

    ```js
    if (condition) return;
    ("value");
    ```

    Est-ce que "value" est la valeur retournée, ou avons-nous une instruction `return` sans valeur suivie d'une instruction expression contenant un littéral de chaîne ?

- Une expression entre parenthèses sur la ligne suivante :

    ```js
    func(parenthesized);
    ```

    Est-ce un appel à `func(parenthesized)`, ou deux instructions expression, une pour `func` et une pour une expression entre parenthèses ?

- Un `-` sur la ligne suivante :

    ```js
    first - second;
    ```

    Est-ce `first - second` -- une soustraction infixe -- ou deux instructions expression, une pour `first` et une pour nier `second` ?

Dans tous ces cas, soit traiter le retour à la ligne comme un séparateur ou non produirait du code valide, mais possiblement pas le code que l'utilisateur veut. À travers les langages, il y a une variété inquiétante de règles utilisées pour décider quels retours à la ligne sont des séparateurs. En voici quelques-unes :

- [Lua][] ignore complètement les retours à la ligne, mais contrôle soigneusement sa grammaire de telle sorte qu'aucun séparateur entre les instructions n'est nécessaire du tout dans la plupart des cas. C'est parfaitement légitime :

    ```lua
    a = 1 b = 2
    ```

    Lua évite le problème du `return` en exigeant qu'une instruction `return` soit la toute dernière instruction d'un bloc. S'il y a une valeur après `return` avant le mot-clé `end`, elle _doit_ être pour le `return`. Pour les deux autres cas, ils autorisent un `;` explicite et attendent des utilisateurs qu'ils l'utilisent. En pratique, cela n'arrive presque jamais car il n'y a pas d'intérêt à une instruction expression parenthésée ou de négation unaire.

- [Go][] gère les retours à la ligne dans le scanner. Si un retour à la ligne apparaît à la suite de l'un d'une poignée de types de tokens qui sont connus pour pouvoir potentiellement terminer une instruction, le retour à la ligne est traité comme un point-virgule. Sinon il est ignoré. L'équipe Go fournit un formateur de code canonique, [gofmt][], et l'écosystème est fervent sur son utilisation, ce qui assure que le code stylé de manière idiomatique fonctionne bien avec cette règle simple.

- [Python][] traite tous les retours à la ligne comme significatifs à moins qu'un antislash explicite soit utilisé à la fin d'une ligne pour la continuer sur la ligne suivante. Cependant, les retours à la ligne n'importe où à l'intérieur d'une paire de crochets (`()`, `[]`, ou `{}`) sont ignorés. Le style idiomatique préfère fortement ces derniers.

    Cette règle fonctionne bien pour Python car c'est un langage hautement orienté instructions. En particulier, la grammaire de Python assure qu'une instruction n'apparaît jamais à l'intérieur d'une expression. C fait la même chose, mais beaucoup d'autres langages qui ont une syntaxe de "lambda" ou de littéral de fonction ne le font pas.

    Un exemple en JavaScript :

    ```js
    console.log(function () {
        statement();
    });
    ```

    Ici, l'_expression_ `console.log()` contient un littéral de fonction qui à son tour contient l'_instruction_ `statement();`.

    Python aurait besoin d'un ensemble de règles différent pour joindre implicitement les lignes si vous pouviez revenir _dans_ une <span name="lambda">instruction</span> où les retours à la ligne devraient devenir significatifs tout en étant encore imbriqués dans des crochets.

<aside name="lambda">

Et maintenant vous savez pourquoi le `lambda` de Python autorise seulement un corps d'expression unique.

</aside>

- La règle d'"[insertion automatique de point-virgule][asi]" de JavaScript est la vraie bizarre. Là où d'autres langages supposent que la plupart des retours à la ligne _sont_ significatifs et que seuls quelques-uns devraient être ignorés dans les instructions multi-lignes, JS suppose le contraire. Il traite tous vos retours à la ligne comme des espaces sans signification _à moins qu'il_ ne rencontre une erreur de parsing. Si c'est le cas, il revient en arrière et essaie de transformer le retour à la ligne précédent en un point-virgule pour obtenir quelque chose de grammaticalement valide.

    Cette note de conception tournerait en une diatribe de conception si j'entrais dans les détails complets de comment cela _fonctionne_ même, et encore moins toutes les diverses façons dont la "solution" de JavaScript est une mauvaise idée. C'est un gâchis. JavaScript est le seul langage que je connaisse où de nombreux guides de style exigent des points-virgules explicites après chaque instruction même si le langage vous laisse théoriquement les élider.

Si vous concevez un nouveau langage, vous devriez presque sûrement _éviter_ un terminateur d'instruction explicite. Les programmeurs sont des créatures de mode comme les autres humains, et les points-virgules sont aussi passés que les MOTS-CLÉS EN MAJUSCULES. Assurez-vous juste de choisir un ensemble de règles qui ont du sens pour la grammaire et les idiomes particuliers de votre langage. Et ne faites pas ce que JavaScript a fait.

</div>

[lua]: https://www.lua.org/pil/1.1.html
[go]: https://golang.org/ref/spec#Semicolons
[gofmt]: https://golang.org/cmd/gofmt/
[python]: https://docs.python.org/3.5/reference/lexical_analysis.html#implicit-line-joining
[asi]: https://www.ecma-international.org/ecma-262/5.1/#sec-7.9
