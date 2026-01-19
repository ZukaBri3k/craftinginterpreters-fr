> La soirée est le plus beau moment de la journée. Vous avez fait votre journée de travail. Maintenant vous pouvez mettre vos pieds sur la table et apprécier.
>
> <cite>Kazuo Ishiguro, <em>Les Vestiges du jour</em></cite>

Si je vivais encore à la Nouvelle-Orléans, j'appellerais ce chapitre un _lagniappe_, un petit quelque chose d'extra donné gratuitement à un client. Vous avez déjà un livre entier et une machine virtuelle complète, mais je veux que vous ayez un peu plus de plaisir à bidouiller sur clox. Cette fois, nous allons pour la pure performance. Nous appliquerons deux optimisations très différentes à notre machine virtuelle. Dans le processus, vous aurez une sensation de mesure et d'amélioration de la performance d'une implémentation de langage -- ou de n'importe quel programme, vraiment.

## Mesurer la Performance

L'**optimisation** signifie prendre une application fonctionnelle et améliorer sa performance. Un programme optimisé fait la même chose, il prend juste moins de ressources pour le faire. La ressource à laquelle nous pensons habituellement lors de l'optimisation est la vitesse d'exécution, mais il peut aussi être important de réduire l'utilisation mémoire, le temps de démarrage, la taille de stockage persistant, ou la bande passante réseau. Toutes les ressources physiques ont un coût -- même si le coût est surtout en temps humain gaspillé -- donc le travail d'optimisation paie souvent.

Il fut un temps dans les premiers jours de l'informatique où un programmeur qualifié pouvait tenir l'architecture matérielle entière et le pipeline du compilateur dans sa tête et comprendre la performance d'un programme juste en pensant vraiment fort. Ces jours sont depuis longtemps révolus, séparés du présent par le microcode, les lignes de cache, la prédiction de branchement, les pipelines de compilateur profonds, et les jeux d'instructions mammouths. Nous aimons prétendre que C est un langage "bas niveau", mais la pile de technologie entre

```c
printf("Hello, world!");
```

et une salutation apparaissant à l'écran est maintenant périlleusement haute.

L'optimisation aujourd'hui est une science empirique. Notre programme est un border collie sprintant à travers la course d'obstacles du matériel. Si nous voulons qu'elle atteigne la fin plus vite, nous ne pouvons pas juste nous asseoir et ruminer sur la physiologie canine jusqu'à ce que l'illumination frappe. Au lieu de cela, nous avons besoin d'_observer_ sa performance, voir où elle trébuche, et ensuite trouver des chemins plus rapides pour elle à prendre.

Tout comme l'entraînement d'agilité est particulier à un chien et une course d'obstacles, nous ne pouvons pas supposer que nos optimisations de machine virtuelle feront courir _tous_ les programmes Lox plus vite sur _tout_ le matériel. Différents programmes Lox stressent différentes zones de la VM, et différentes architectures ont leurs propres forces et faiblesses.

### Benchmarks

Quand nous ajoutons une nouvelle fonctionnalité, nous validons la correction en écrivant des tests -- des programmes Lox qui utilisent une fonctionnalité et valident le comportement de la VM. Les tests épinglent la sémantique et assurent que nous ne brisons pas les fonctionnalités existantes quand nous en ajoutons de nouvelles. Nous avons des besoins similaires quand il s'agit de performance :

1.  Comment validons-nous qu'une optimisation _améliore_ bien la performance, et de combien ?

2.  Comment assurons-nous que d'autres changements non liés ne _régressent_ pas la performance ?

Les programmes Lox que nous écrivons pour accomplir ces buts sont des **benchmarks**. Ce sont des programmes soigneusement fabriqués qui stressent quelque partie de l'implémentation du langage. Ils mesurent non _ce que_ le programme fait, mais <span name="much">_combien_</span> de temps il prend pour le faire.

<aside name="much">

La plupart des benchmarks mesurent le temps d'exécution. Mais, bien sûr, vous vous trouverez éventuellement ayant besoin d'écrire des benchmarks qui mesurent l'allocation mémoire, combien de temps est passé dans le ramasse-miettes, le temps de démarrage, etc.

</aside>

En mesurant la performance d'un benchmark avant et après un changement, vous pouvez voir ce que votre changement fait. Quand vous atterrissez une optimisation, tous les tests devraient se comporter exactement de la même manière qu'ils faisaient avant, mais avec espoir les benchmarks courent plus vite.

Une fois que vous avez une <span name="js">_suite_</span> entière de benchmarks, vous pouvez mesurer non seulement _qu_'une optimisation change la performance, mais sur quelles _sortes_ de code. Souvent vous trouverez que quelques benchmarks deviennent plus rapides tandis que d'autres deviennent plus lents. Ensuite vous avez à prendre des décisions difficiles sur pour quelles sortes de code votre implémentation de langage optimise.

La suite de benchmarks que vous choisissez d'écrire est une partie clé de cette décision. De la même manière que vos tests encodent vos choix autour de ce à quoi le comportement correct ressemble, vos benchmarks sont l'incarnation de vos priorités quand il s'agit de performance. Ils guideront quelles optimisations vous implémentez, donc choisissez vos benchmarks soigneusement, et n'oubliez pas de réfléchir périodiquement sur s'ils vous aident à atteindre vos plus larges buts.

<aside name="js">

Dans la prolifération précoce des VMs JavaScript, la première suite de benchmark largement utilisée était SunSpider de WebKit. Durant les guerres de navigateurs, les gens du marketing utilisaient les résultats SunSpider pour clamer que leur navigateur était le plus rapide. Cela incitait hautement les hackers de VM à optimiser pour ces benchmarks.

Malheureusement, les programmes SunSpider ne correspondaient souvent pas au JavaScript du monde réel. Ils étaient surtout des microbenchmarks -- de minuscules programmes jouets qui se complétaient rapidement. Ces benchmarks pénalisent les compilateurs just-in-time complexes qui démarrent plus lentement mais deviennent _beaucoup_ plus rapides une fois que le JIT a eu assez de temps pour optimiser et recompiler les chemins de code chauds. Cela mettait les hackers de VM dans la position malheureuse d'avoir à choisir entre faire devenir meilleurs les nombres SunSpider, ou optimiser réellement les sortes de programmes que les vrais utilisateurs couraient.

L'équipe V8 de Google a répondu en partageant leur suite de benchmark Octane, qui était plus proche du code du monde réel à l'époque. Des années plus tard, comme les motifs d'utilisation de JavaScript continuaient d'évoluer, même Octane a survécu à son utilité. Attendez-vous à ce que vos benchmarks évoluent comme l'écosystème de votre langage le fait.

Rappelez-vous, le but ultime est de rendre les _programmes utilisateur_ plus rapides, et les benchmarks sont seulement un proxy pour cela.

</aside>

Le benchmarking est un art subtil. Comme les tests, vous avez besoin de balancer ne pas sur-ajuster à votre implémentation tout en assurant que le benchmark chatouille réellement les chemins de code dont vous vous souciez. Quand vous mesurez la performance, vous avez besoin de compenser pour la variance causée par l'étranglement CPU, le cache, et d'autres bizarreries bizarres du matériel et du système d'exploitation. Je ne vous donnerai pas un sermon entier ici, mais traitez le benchmarking comme sa propre compétence qui s'améliore avec la pratique.

### Profilage

OK, donc vous avez quelques benchmarks maintenant. Vous voulez les faire aller plus vite. Maintenant quoi ? Tout d'abord, supposons que vous avez fait tout le travail évident, facile. Vous utilisez les bons algorithmes et structures de données -- ou, au moins, vous n'utilisez pas ceux qui sont agressivement faux. Je ne considère pas utiliser une table de hachage au lieu d'une recherche linéaire à travers un énorme tableau non trié de "l'optimisation" tant que du "bon génie logiciel".

Puisque le matériel est trop complexe pour raisonner sur la performance de notre programme depuis les premiers principes, nous devons aller sur le terrain. Cela signifie _profiler_. Un **profileur**, si vous n'en avez jamais utilisé un, est un outil qui court votre <span name="program">programme</span> et piste l'utilisation des ressources matérielles comme le code exécute. Les simples vous montrent combien de temps a été passé dans chaque fonction dans votre programme. Les sophistiqués journalisent les miss de cache de données, les miss de cache d'instruction, les mauvaises prédictions de branchement, les allocations mémoire, et toutes sortes d'autres métriques.

<aside name="program">

"Votre programme" ici signifie la VM Lox elle-même courant quelque _autre_ programme Lox. Nous essayons d'optimiser clox, pas le script Lox de l'utilisateur. Bien sûr, le choix de quel programme Lox charger dans notre VM affectera hautement quelles parties de clox sont stressées, ce qui est pourquoi les benchmarks sont si importants.

Un profileur ne nous _montrera pas_ combien de temps est passé dans chaque fonction _Lox_ dans le script étant couru. Nous aurions à écrire notre propre "profileur Lox" pour faire cela, ce qui est légèrement hors de portée pour ce livre.

</aside>

Il y a beaucoup de profileurs là-dehors pour divers systèmes d'exploitation et langages. Sur n'importe quelle plateforme que vous programmez, cela vaut la peine de devenir familier avec un profileur décent. Vous n'avez pas besoin d'être un maître. J'ai appris des choses en quelques minutes de jeter un programme à un profileur qui m'auraient pris des _jours_ à découvrir par moi-même à travers essai et erreur. Les profileurs sont des outils merveilleux, magiques.

## Sondage de Table de Hachage Plus Rapide

Assez pontifié, faisons monter quelques graphiques de performance vers la droite. La première optimisation que nous ferons, il s'avère, est à propos du _plus minuscule_ changement possible que nous pourrions faire à notre VM.

Quand j'ai d'abord fait fonctionner la machine virtuelle à bytecode dont clox est descendu, j'ai fait ce que n'importe quel hacker de VM se respectant ferait. J'ai bricolé une paire de benchmarks, démarré un profileur, et couru ces scripts à travers mon interpréteur. Dans un langage typé dynamiquement comme Lox, une large fraction du code utilisateur est des accès de champ et appels de méthode, donc un de mes benchmarks ressemblait à quelque chose comme ceci :

```lox
class Zoo {
  init() {
    this.aardvark = 1;
    this.baboon   = 1;
    this.cat      = 1;
    this.donkey   = 1;
    this.elephant = 1;
    this.fox      = 1;
  }
  ant()    { return this.aardvark; }
  banana() { return this.baboon; }
  tuna()   { return this.cat; }
  hay()    { return this.donkey; }
  grass()  { return this.elephant; }
  mouse()  { return this.fox; }
}

var zoo = Zoo();
var sum = 0;
var start = clock();
while (sum < 100000000) {
  sum = sum + zoo.ant()
            + zoo.banana()
            + zoo.tuna()
            + zoo.hay()
            + zoo.grass()
            + zoo.mouse();
}

print clock() - start;
print sum;
```

<aside name="sum" class="bottom">

Une autre chose que ce benchmark est prudent de faire est d'_utiliser_ le résultat du code qu'il exécute. En calculant une somme roulante et en affichant le résultat, nous assurons que la VM _doit_ exécuter tout ce code Lox. C'est une habitude importante. Contrairement à notre VM Lox simple, beaucoup de compilateurs font une élimination de code mort agressive et sont assez intelligents pour jeter un calcul dont le résultat n'est jamais utilisé.

Plus d'un hacker de langage de programmation a été impressionné par la performance flamboyante d'une VM sur quelque benchmark, seulement pour réaliser que c'est parce que le compilateur a optimisé le programme benchmark entier vers rien.

</aside>

Si vous n'avez jamais vu un benchmark avant, cela pourrait sembler risible. _Quoi_ se passe ici ? Le programme lui-même n'a pas l'intention de <span name="sum">faire</span> quoi que ce soit d'utile. Ce qu'il fait est d'appeler un tas de méthodes et d'accéder à un tas de champs puisque ce sont les parties du langage qui nous intéressent. Les champs et méthodes vivent dans des tables de hachage, donc il prend soin de peupler au moins <span name="more">_quelques_</span> clés intéressantes dans ces tables. C'est tout enveloppé dans une grosse boucle pour assurer que notre profileur a assez de temps d'exécution pour creuser dedans et voir où les cycles vont.

<aside name="more">

Si vous voulez vraiment benchmarker la performance de table de hachage, vous devriez utiliser beaucoup de tables de différentes tailles. Les six clés que nous ajoutons à chaque table ici ne sont même pas suffisantes pour passer au-dessus du seuil minimum de huit éléments de notre table de hachage. Mais je ne voulais pas jeter un énorme script benchmark à vous. Sentez-vous libre d'ajouter plus de bestioles et friandises si vous aimez.

</aside>

Avant que je vous dise ce que mon profileur m'a montré, passez une minute à prendre quelques devinettes. Où dans la base de code de clox pensez-vous que la VM a passé la plupart de son temps ? Y a-t-il du code que nous avons écrit dans les chapitres précédents que vous suspectez être particulièrement lent ?

Voici ce que j'ai trouvé : Naturellement, la fonction avec le plus grand temps inclusif est `run()`. (**Temps inclusif** signifie le temps total passé dans quelque fonction et toutes les autres fonctions qu'elle appelle -- le temps total entre quand vous entrez dans la fonction et quand elle retourne.) Puisque `run()` est la boucle d'exécution de bytecode principale, elle pilote tout.

À l'intérieur de `run()`, il y a de petits morceaux de temps saupoudrés dans divers cas dans le switch bytecode pour des instructions communes comme `OP_POP`, `OP_RETURN`, et `OP_ADD`. Les grosses instructions lourdes sont `OP_GET_GLOBAL` avec 17% du temps d'exécution, `OP_GET_PROPERTY` à 12%, et `OP_INVOKE` qui prend un énorme 42% du temps d'exécution total.

Donc nous avons trois points chauds à optimiser ? En fait, non. Parce qu'il s'avère que ces trois instructions passent presque tout leur temps à l'intérieur d'appels à la même fonction : `tableGet()`. Cette fonction réclame un entier 72% du temps d'exécution (encore, inclusif). Maintenant, dans un langage typé dynamiquement, nous nous attendons à passer un bon peu de temps à chercher des trucs dans des tables de hachage -- c'est une sorte de prix du dynamisme. Mais, quand même, _wow._

### Enveloppement de clé lent

Si vous jetez un coup d'œil à `tableGet()`, vous verrez que c'est surtout une enveloppe autour d'un appel à `findEntry()` où la recherche réelle de table de hachage se produit. Pour rafraîchir votre mémoire, la voici en entier :

```c
static Entry* findEntry(Entry* entries, int capacity,
                        ObjString* key) {
  uint32_t index = key->hash % capacity;
  Entry* tombstone = NULL;

  for (;;) {
    Entry* entry = &entries[index];
    if (entry->key == NULL) {
      if (IS_NIL(entry->value)) {
        // Empty entry.
        return tombstone != NULL ? tombstone : entry;
      } else {
        // We found a tombstone.
        if (tombstone == NULL) tombstone = entry;
      }
    } else if (entry->key == key) {
      // We found the key.
      return entry;
    }

    index = (index + 1) % capacity;
  }
}
```

Lors de l'exécution de ce benchmark précédent -- sur ma machine, au moins -- la VM passe 70% du temps d'exécution total sur _une ligne_ dans cette fonction. Des devinettes sur laquelle ? Non ? C'est celle-ci :

```c
  uint32_t index = key->hash % capacity;
```

Cette déréférence de pointeur n'est pas le problème. C'est le petit `%`. Il s'avère que l'opérateur modulo est _vraiment_ lent. Beaucoup plus lent que d'autres opérateurs <span name="division">arithmétiques</span>. Pouvons-nous faire quelque chose de mieux ?

<aside name="division">

Le pipelining rend difficile de parler à propos de la performance d'une instruction CPU individuelle, mais pour vous donner une sensation des choses, la division et le modulo sont environ 30-50 _fois_ plus lents que l'addition et la soustraction sur x86.

</aside>

Dans le cas général, il est vraiment dur de ré-implémenter un opérateur arithmétique fondamental dans le code utilisateur d'une manière qui est plus rapide que ce que le CPU lui-même peut faire. Après tout, notre code C compile ultimement vers les propres opérations arithmétiques du CPU. S'il y avait des trucs que nous pouvions utiliser pour aller plus vite, la puce serait déjà en train de les utiliser.

Cependant, nous pouvons prendre avantage du fait que nous savons plus sur notre problème que le CPU ne sait. Nous utilisons le modulo ici pour prendre un code de hachage de chaîne de clé et l'envelopper pour tenir dans les bornes du tableau d'entrées de la table. Ce tableau commence à huit éléments et grandit par un facteur de deux chaque fois. Nous savons -- et le CPU et le compilateur C ne savent pas -- que la taille de notre table est toujours une puissance de deux.

Parce que nous sommes des bidouilleurs de bits intelligents, nous connaissons un moyen plus rapide de calculer le reste d'un nombre modulo une puissance de deux : **le masquage de bits**. Disons que nous voulons calculer 229 modulo 64. La réponse est 37, ce qui n'est pas particulièrement apparent en décimal, mais est plus clair quand vous voyez ces nombres en binaire :

<img src="image/optimization/mask.png" alt="Les motifs de bits résultant de 229 % 64 = 37 et 229 &amp; 63 = 37." />

Sur le côté gauche de l'illustration, notez comment le résultat (37) est simplement le dividende (229) avec les deux bits les plus hauts rasés ? Ces deux bits les plus hauts sont les bits à ou à la gauche du bit 1 unique du diviseur.

Sur le côté droit, nous obtenons le même résultat en prenant 229 et en le faisant un <span class="small-caps">ET</span> bit à bit avec 63, qui est un de moins que notre puissance de deux diviseur original. Soustraire un d'une puissance de deux vous donne une série de bits 1. C'est exactement le masque dont nous avons besoin afin de dépouiller ces deux bits les plus à gauche.

En d'autres termes, vous pouvez calculer un nombre modulo n'importe quelle puissance de deux simplement en le faisant un <span class="small-caps">ET</span> bit à bit avec cette puissance de deux moins un. Je ne suis pas assez mathématicien pour vous _prouver_ que cela fonctionne, mais si vous y réfléchissez, cela devrait faire sens. Nous pouvons remplacer cet opérateur modulo lent avec un décrément très rapide et un <span class="small-caps">ET</span> bit à bit. Nous changeons simplement la ligne de code offensante vers ceci :

^code initial-index (2 before, 1 after)
Les CPUs aiment les opérateurs binaires, donc il est dur d'<span name="sub">améliorer</span> cela.

<aside name="sub">

Une autre amélioration potentielle est d'éliminer le décrément en stockant le masque de bits directement au lieu de la capacité. Dans mes tests, cela ne faisait pas de différence. Le pipelining d'instruction rend certaines opérations essentiellement gratuites si le CPU est goulot-d'étranglé ailleurs.

</aside>

Notre recherche par sondage linéaire peut avoir besoin d'envelopper autour de la fin du tableau, donc il y a un autre modulo dans `findEntry()` à mettre à jour.

^code next-index (4 before, 1 after)

Cette ligne ne s'est pas montrée dans le profileur puisque la plupart des recherches n'enveloppent pas.

La fonction `findEntry()` a une fonction sœur, `tableFindString()` qui fait une recherche de table de hachage pour interner les chaînes. Nous pouvons aussi bien appliquer les mêmes optimisations là-bas aussi. Cette fonction est appelée seulement lors de l'internement des chaînes, ce qui n'était pas lourdement stressé par notre benchmark. Mais un programme Lox qui créait beaucoup de chaînes pourrait notablement bénéficier de ce changement.

^code find-string-index (2 before, 2 after)

Et aussi quand le sondage linéaire enveloppe autour.

^code find-string-next (3 before, 1 after)

Voyons si nos correctifs valaient la peine. J'ai ajusté ce benchmark zoologique pour compter combien de <span name="batch">lots</span> de 10 000 appels il peut courir en dix secondes. Plus de lots égale une performance plus rapide. Sur ma machine utilisant le code non optimisé, le benchmark passe à travers 3 192 lots. Après cette optimisation, cela saute à 6 249.

<img src="image/optimization/hash-chart.png" alt="Graphique à barres comparant la performance avant et après l'optimisation." />

C'est presque exactement deux fois plus de travail dans la même quantité de temps. Nous avons rendu la VM deux fois plus rapide (mise en garde habituelle : sur ce benchmark). C'est une victoire massive quand il s'agit d'optimisation. Habituellement vous vous sentez bien si vous pouvez gratter quelques points de pourcentage ici ou là. Puisque les méthodes, champs, et variables globales sont si prévalents dans les programmes Lox, cette minuscule optimisation améliore la performance à travers le tableau. Presque chaque programme Lox bénéficie.

<aside name="batch">

Notre benchmark original fixait la quantité de _travail_ et ensuite mesurait le _temps_. Changer le script pour compter combien de lots d'appels il peut faire en dix secondes fixe le temps et mesure le travail. Pour les comparaisons de performance, j'aime cette dernière mesure parce que le nombre rapporté représente la _vitesse_. Vous pouvez directement comparer les nombres avant et après une optimisation. Lors de la mesure du temps d'exécution, vous devez faire un peu d'arithmétique pour arriver à une bonne mesure relative de la performance.

</aside>

Maintenant, le point de cette section n'est _pas_ que l'opérateur modulo est profondément maléfique et vous devriez l'écraser hors de chaque programme que vous écrivez jamais. Il n'est pas non plus que la micro-optimisation est une compétence d'ingénierie vitale. Il est rare qu'un problème de performance ait une solution aussi étroite et efficace. Nous avons eu de la chance.

Le point est que nous ne _savions_ pas que l'opérateur modulo était une perte de performance jusqu'à ce que notre profileur nous le dise ainsi. Si nous avions erré autour de la base de code de notre VM aveuglément devinant aux points chauds, nous ne l'aurions probablement pas remarqué. Ce que je veux que vous emportiez de cela est combien il est important d'avoir un profileur dans votre boîte à outils.

Pour renforcer ce point, allons de l'avant et courons le benchmark original dans notre VM maintenant optimisée et voyons ce que le profileur nous montre. Sur ma machine, `tableGet()` est encore un morceau assez large du temps d'exécution. C'est à s'attendre pour un langage typé dynamiquement. Mais il a chuté de 72% du temps d'exécution total vers le bas à 35%. C'est beaucoup plus en ligne avec ce que nous aimerions voir et montre que notre optimisation n'a pas juste rendu le programme plus rapide, mais rendu plus rapide _de la façon que nous attendions_. Les profileurs sont aussi utiles pour vérifier les solutions qu'ils sont pour découvrir les problèmes.

## Boxing NaN

Cette prochaine optimisation a une sensation très différente. Heureusement, malgré le nom bizarre, elle n'implique pas de frapper votre grand-mère (NdT : jeu de mots sur "boxing" = boxe). C'est différent, mais pas, genre, _si_ différent. Avec notre optimisation précédente, le profileur nous disait où le problème était, et nous devions simplement utiliser un peu d'ingéniosité pour arriver avec une solution.

Cette optimisation est plus subtile, et ses effets de performance plus dispersés à travers la machine virtuelle. Le profileur ne nous aidera pas à venir avec ceci. Au lieu de cela, cela a été inventé par <span name="someone">quelqu'un</span> pensant profondément aux niveaux les plus bas de l'architecture machine.

<aside name="someone">

Je ne suis pas sûr de qui est venu le premier avec ce truc. La source la plus ancienne que je peux trouver est le papier de 1993 de David Gudeman "Representing Type Information in Dynamically Typed Languages". Tout le monde d'autre cite cela. Mais Gudeman lui-même dit que le papier n'est pas un travail original, mais au lieu de cela "rassemble un corps de folklore".

Peut-être l'inventeur a été perdu dans les brumes du temps, ou peut-être cela a été réinventé un certain nombre de fois. Quiconque rumine sur IEEE 754 assez longtemps commence probablement à penser à essayer de fourrer quelque chose d'utile dans tous ces bits NaN inutilisés.

</aside>

Comme le titre dit, cette optimisation est appelée **NaN boxing** (mise en boîte NaN) ou parfois **NaN tagging** (étiquetage NaN). Personnellement j'aime le dernier nom parce que "boxing" tend à impliquer quelque sorte de représentation allouée sur le tas, mais le premier semble être le terme le plus largement utilisé. Cette technique change comment nous représentons les valeurs dans la VM.

Sur une machine 64 bits, notre type Value prend 16 octets. La structure a deux champs, une étiquette de type et une union pour la charge utile. Les plus grands champs dans l'union sont un pointeur Obj et un double, qui sont tous deux 8 octets. Pour garder le champ union aligné à une frontière de 8 octets, le compilateur ajoute du remplissage après l'étiquette aussi :

<img src="image/optimization/union.png" alt="Disposition des octets de l'union étiquetée Value de 16 octets." />

C'est assez gros. Si nous pouvions couper cela vers le bas, alors la VM pourrait empaqueter plus de valeurs dans la même quantité de mémoire. La plupart des ordinateurs ont plein de RAM ces jours-ci, donc les économies de mémoire directe ne sont pas une énorme affaire. Mais une représentation plus petite signifie plus de Values tenant dans une ligne de cache. Cela signifie moins de miss de cache, ce qui affecte la _vitesse_.

Si les Values ont besoin d'être alignées à leur plus grande taille de charge utile, et qu'un nombre Lox ou un pointeur Obj a besoin d'un plein 8 octets, comment pouvons-nous devenir plus petits ? Dans un langage typé dynamiquement comme Lox, chaque valeur a besoin de porter non seulement sa charge utile, mais assez d'information supplémentaire pour déterminer le type de la valeur à l'exécution. Si un nombre Lox utilise déjà les pleins 8 octets, où pourrions-nous écureuiller une paire de bits supplémentaires pour dire au runtime "ceci est un nombre" ?

C'est un des problèmes pérennes pour les hackers de langage dynamique. Cela les embête particulièrement parce que les langages typés statiquement n'ont généralement pas ce problème. Le type de chaque valeur est connu à la compilation, donc aucune mémoire supplémentaire n'est nécessaire à l'exécution pour le suivre. Quand votre compilateur C compile un int 32 bits, la variable résultante obtient _exactement_ 32 bits de stockage.

Les gens du langage dynamique détestent perdre du terrain face au camp statique, donc ils sont venus avec un certain nombre de manières très intelligentes d'empaqueter l'information de type et une charge utile dans un petit nombre de bits. NaN boxing est l'une de celles-ci. C'est un ajustement particulièrement bon pour des langages comme JavaScript et Lua, où tous les nombres sont flottants double-précision. Lox est dans ce même bateau.

### Ce qui est (et n'est pas) un nombre ?

Avant que nous commencions à optimiser, nous avons besoin de vraiment comprendre comment notre ami le CPU représente les nombres à virgule flottante. Presque toutes les machines aujourd'hui utilisent le même schéma, encodé dans le vénérable parchemin [IEEE 754][754], connu des mortels comme le "Standard IEEE pour l'Arithmétique à Virgule Flottante".

[754]: https://fr.wikipedia.org/wiki/IEEE_754

Aux yeux de votre ordinateur, un nombre à virgule flottante IEEE <span name="hyphen">64 bits</span>, double précision ressemble à ceci :

<aside name="hyphen">

C'est beaucoup de traits d'union pour une phrase.

</aside>

<img src="image/optimization/double.png" alt="Représentation bit d'un double IEEE 754." />

- Commençant depuis la droite, les premiers 52 bits sont la **fraction**, **mantisse**, ou **significande** bits. Ils représentent les chiffres significatifs du nombre, comme un entier binaire.

- À côté de cela sont 11 bits d'**exposant**. Ceux-ci vous disent de combien loin la mantisse est décalée du point décimal (enfin, binaire).

- Le bit le plus haut est le <span name="sign">**bit de signe**</span>, qui indique si le nombre est positif ou négatif.

Je sais que c'est un peu vague, mais ce chapitre n'est pas une plongée profonde sur la représentation virgule flottante. Si vous voulez savoir comment l'exposant et la mantisse jouent ensemble, il y a déjà de meilleures explications là-dehors que je pourrais écrire.

<aside name="sign">

Puisque le bit de signe est toujours présent, même si le nombre est zéro, cela implique que "zéro positif" et "zéro négatif" ont différentes représentations binaires, et en effet, IEEE 754 distingue ceux-ci.

</aside>

La partie importante pour nos buts est que la spécification découpe un exposant à cas spécial. Quand tous les bits d'exposant sont mis, alors au lieu de juste représenter un nombre vraiment gros, la valeur a une signification différente. Ces valeurs sont des valeurs "Pas un Nombre" (hence, **NaN**). Elles représentent des concepts comme l'infini ou le résultat d'une division par zéro.

_Tout_ double dont les bits d'exposant sont tous mis est un NaN, indépendamment des bits de mantisse. Cela signifie qu'il y a des tas et des tas de motifs de bits NaN _différents_. IEEE 754 divise ceux-ci en deux catégories. Les valeurs où le bit de mantisse le plus haut est 0 sont appelées **NaNs signalants** (signalling NaNs), et les autres sont **NaNs silencieux** (quiet NaNs). Les NaNs signalants sont destinés à être le résultat de calculs erronés, comme la division par zéro. Une puce <span name="abort">peut</span> détecter quand une de ces valeurs est produite et avorter un programme complètement. Ils peuvent s'auto-détruire si vous essayez d'en lire un.

<aside name="abort">

Je ne sais pas si de quelconques CPUs piègent réellement les NaNs signalants et avortent. La spec dit juste qu'ils _pourraient_.

</aside>

Les NaNs silencieux sont supposés être plus sûrs à utiliser. Ils ne représentent pas de valeurs numériques utiles, mais ils devraient au moins ne pas mettre votre main en feu si vous les touchez.

Chaque double avec tous ses bits d'exposant mis et son bit de mantisse le plus haut mis est un NaN silencieux. Cela laisse 52 bits non comptabilisés. Nous éviterons l'un de ceux-ci pour que nous ne marchions pas sur la valeur "QNaN Floating-Point Indefinite" d'Intel, nous laissant 51 bits. Ces bits restants peuvent être n'importe quoi. Nous parlons de 2 251 799 813 685 248 motifs de bits NaN silencieux uniques.

<img src="image/optimization/nan.png" alt="Les bits dans un double qui le rendent un NaN silencieux." />

Cela signifie qu'un double 64 bits a assez de place pour stocker toutes les diverses différentes valeurs numériques à virgule flottante et _aussi_ a de la place pour un autre 51 bits de données que nous pouvons utiliser comme nous voulons. C'est plein de place pour mettre de côté une paire de motifs de bits pour représenter les valeurs `nil`, `true`, et `false` de Lox. Mais qu'en est-il des pointeurs Obj ? Les pointeurs n'ont-ils pas besoin d'un plein 64 bits aussi ?

Heureusement, nous avons un autre truc dans notre autre manche. Oui, techniquement les pointeurs sur une architecture 64 bits sont 64 bits. Mais, aucune architecture je connais de n'utilise réellement cet espace d'adresse entier. Au lieu de cela, la plupart des puces largement utilisées aujourd'hui utilisent seulement jamais les <span name="48">48</span> bits bas. Les 16 bits restants sont soit non spécifiés ou toujours zéro.

<aside name="48">

48 bits est assez pour adresser 262 144 gigaoctets de mémoire. Les systèmes d'exploitation modernes donnent aussi à chaque processus son propre espace d'adresse, donc cela devrait être plein.

</aside>

Si nous avons 51 bits, nous pouvons fourrer un pointeur 48 bits là-dedans avec trois bits à épargner. Ces trois bits sont juste assez pour stocker de minuscules étiquettes de type pour distinguer entre `nil`, Booléens, et pointeurs Obj.

C'est ça le NaN boxing. À l'intérieur d'un simple double 64 bits, vous pouvez stocker toutes les différentes valeurs numériques à virgule flottante, un pointeur, ou n'importe laquelle d'une paire d'autres valeurs sentinelles spéciales. Moitié l'utilisation mémoire de notre structure Value courante, tout en retenant toute la fidélité.

Ce qui est particulièrement sympa à propos de cette représentation est qu'il n'y a pas besoin de _convertir_ une valeur double numérique en une forme "mise en boîte". Les nombres Lox _sont_ juste des doubles 64 bits normaux. Nous avons encore besoin de _vérifier_ leur type avant que nous les utilisions, puisque Lox est typé dynamiquement, mais nous n'avons pas besoin de faire de décalage de bit ou d'indirection de pointeur pour aller de "valeur" à "nombre".

Pour les autres types de valeur, il y a une étape de conversion, bien sûr. Mais, heureusement, notre VM cache tout le mécanisme pour aller des valeurs aux types bruts derrière une poignée de macros. Réécrivez celles-ci pour implémenter le NaN boxing, et le reste de la VM devrait juste fonctionner.

### Support conditionnel

Je sais que les détails de cette nouvelle représentation ne sont pas clairs dans votre tête encore. Ne vous inquiétez pas, ils se cristalliseront comme nous travaillons à travers l'implémentation. Avant que nous arrivions à cela, nous allons mettre un peu d'échafaudage de temps de compilation en place.

Pour notre optimisation précédente, nous avons réécrit le code lent précédent et l'avons appelé fait. C'est un peu différent. Le NaN boxing compte sur quelques détails très bas niveau de comment une puce représente les nombres à virgule flottante et les pointeurs. Il fonctionne _probablement_ sur la plupart des CPUs que vous êtes susceptible de rencontrer, mais vous ne pouvez jamais être totalement sûr.

Cela craindrait si notre VM perdait complètement le support pour une architecture juste à cause de sa représentation de valeur. Pour éviter cela, nous maintiendrons le support pour _à la fois_ la vieille implémentation union étiquetée de Value et la nouvelle forme NaN-boxed. Nous sélectionnons quelle représentation nous voulons à la compilation utilisant ce drapeau :

^code define-nan-boxing (2 before, 1 after)

Si c'est défini, la VM utilise la nouvelle forme. Sinon, elle revient au vieux style. Les quelques morceaux de code qui se soucient des détails de la représentation de valeur -- principalement la poignée de macros pour envelopper et déballer les Values -- varient basé sur si ce drapeau est mis. Le reste de la VM peut continuer le long de son chemin joyeux.

La plupart du travail se passe dans le module "value" où nous ajoutons une section pour le nouveau type.

^code nan-boxing (2 before, 1 after)

Quand le NaN boxing est activé, le type réel d'une Value est un entier plat, non signé de 64 bits. Nous pourrions utiliser double au lieu, ce qui rendrait les macros pour traiter les nombres Lox un peu plus simples. Mais toutes les autres macros ont besoin de faire des opérations binaires et uint64_t est un type beaucoup plus amical pour cela. En dehors de ce module, le reste de la VM ne se soucie pas vraiment d'une manière ou d'une autre.

Avant que nous commencions à ré-implémenter ces macros, nous fermons la branche `#else` du `#ifdef` à la fin des définitions pour la vieille représentation.

^code end-if-nan-boxing (1 before, 2 after)

Notre tâche restante est simplement de remplir cette première section `#ifdef` avec les nouvelles implémentations de tout le trucs déjà dans le côté `#else`. Nous travaillerons à travers cela un type de valeur à la fois, du plus facile au plus dur.

### Nombres

Nous commencerons avec les nombres puisqu'ils ont la représentation la plus directe sous NaN boxing. Pour "convertir" un double C en une Value clox NaN-boxed, nous n'avons pas besoin de toucher un seul bit -- la représentation est exactement la même. Mais nous avons bien besoin de convaincre notre compilateur C de ce fait, ce que nous avons rendu plus dur en définissant Value pour être uint64_t.

Nous avons besoin d'amener le compilateur à prendre un ensemble de bits qu'il pense être un double et utiliser ces mêmes bits comme un uint64_t, ou vice versa. Ceci est appelé **type punning** (jeu de mots de type). Les programmeurs C et C++ ont fait cela depuis les jours des pantalons à pattes d'eph et des 8 pistes, mais les spécifications de langage ont <span name="hesitate">hésité</span> à dire laquelle des nombreuses façons de faire cela est officiellement sanctionnée.

<aside name="hesitate" class="bottom">

Les auteurs de spec n'aiment pas le type punning parce qu'il rend l'optimisation plus dure. Une technique d'optimisation clé est de réordonner les instructions pour remplir les pipelines d'exécution du CPU. Un compilateur peut réordonner le code seulement quand le faire n'a pas d'effet visible par l'utilisateur, évidemment.

Les pointeurs rendent ça plus dur. Si deux pointeurs pointent vers la même valeur, alors une écriture à travers l'un et une lecture à travers l'autre ne peut pas être réordonnée. Mais qu'en est-il de deux pointeurs de types _différents_ ? Si ceux-ci pouvaient pointer vers le même objet, alors essentiellement _n'importe quels_ deux pointeurs pourraient être des alias vers la même valeur. Cela limite drastiquement la quantité de code que le compilateur est libre de réarranger.

Pour éviter cela, les compilateurs veulent assumer le **strict aliasing** (aliasing strict) -- des pointeurs de types incompatibles ne peuvent pas pointer vers la même valeur. Le type punning, par nature, brise cette hypothèse.

</aside>

Je connais une façon de convertir un `double` vers `Value` et retour que je crois est supportée par à la fois les specs C et C++. Malheureusement, elle ne tient pas dans une expression unique, donc les macros de conversion doivent appeler des fonctions d'aide. Voici la première macro :

^code number-val (1 before, 2 after)

Cette macro passe le double ici :

^code num-to-value (1 before, 2 after)

Je sais, bizarre, vrai ? La façon de traiter une série d'octets comme ayant un type différent sans changer leur valeur du tout est `memcpy()` ? Cela semble horriblement lent : Créez une variable locale. Passez son adresse au système d'exploitation à travers un appel système pour copier quelques octets. Ensuite renvoyez le résultat, qui est exactement les mêmes octets que l'entrée. Heureusement, parce que ceci _est_ l'idiome supporté pour le type punning, la plupart des compilateurs reconnaissent le motif et optimisent le `memcpy()` entièrement.

"Déballer" un nombre Lox est l'image miroir.

^code as-number (1 before, 2 after)

Cette macro appelle cette fonction :

^code value-to-num (1 before, 2 after)

Cela fonctionne exactement pareil sauf que nous échangeons les types. Encore, le compilateur éliminera tout ça. Même si ces appels à `memcpy()` disparaîtront, nous avons encore besoin de montrer au compilateur _quel_ `memcpy()` nous appelons donc nous avons aussi besoin d'un <span name="union">include</span>.

<aside name="union" class="bottom">

Si vous vous trouvez avec un compilateur qui n'optimise pas le `memcpy()` pour le faire disparaître, essayez ceci au lieu :

```c
double valueToNum(Value value) {
  union {
    uint64_t bits;
    double num;
  } data;
  data.bits = value;
  return data.num;
}
```

</aside>

^code include-string (1 before, 2 after)

C'était beaucoup de code pour ultimement ne rien faire sauf faire taire le vérificateur de type C. Faire un _test_ de type à l'exécution sur un nombre Lox est un peu plus intéressant. Si tout ce que nous avons sont exactement les bits pour un double, comment disons-nous que c'_est_ un double ? Il est temps d'obtenir un peu de bidouillage de bits.

^code is-number (1 before, 2 after)

Nous savons que chaque Value qui n'est _pas_ un nombre utilisera une représentation spéciale NaN silencieux. Et nous présumons que nous avons correctement évité n'importe quelle des représentations NaN significatives qui peuvent réellement être produites en faisant de l'arithmétique sur les nombres.

Si le double a tous ses bits NaN mis, et le bit NaN silencieux mis, et un de plus pour faire bonne mesure, nous pouvons être <span name="certain">assez certains</span> que c'est l'un des motifs de bits que nous avons nous-mêmes mis de côté pour d'autres types. Pour vérifier cela, nous masquons tous les bits sauf notre ensemble de bits NaN silencieux. Si _tous_ ces bits sont mis, ce doit être une valeur NaN-boxed de quelque autre type Lox. Sinon, c'est réellement un nombre.

<aside name="certain">

Assez certain, mais pas strictement garanti. Pour autant que je sache, il n'y a rien empêchant un CPU de produire une valeur NaN comme le résultat de quelque opération dont la représentation binaire entre en collision avec celles que nous avons réclamées. Mais dans mes tests à travers un nombre d'architectures, je ne l'ai pas vu arriver.

</aside>

L'ensemble des bits NaN silencieux est déclaré comme ceci :

^code qnan (1 before, 2 after)

Ce serait bien si C supportait les littéraux binaires. Mais si vous faites la conversion, vous verrez que la valeur est la même que ceci :

<img src="image/optimization/qnan.png" alt="Les bits NaN silencieux." />

C'est exactement tous les bits d'exposant, plus le bit NaN silencieux, plus un extra pour esquiver cette valeur Intel.

### Nil, true, et false

Le type suivant à gérer est `nil`. C'est assez simple puisqu'il y a seulement une valeur `nil` et ainsi nous avons besoin de seulement un motif de bit unique pour le représenter. Il y a deux autres valeurs singletons, les deux Booléens, `true` et `false`. Cela appelle pour trois motifs de bits uniques au total.

Deux bits nous donnent quatre combinaisons différentes, ce qui est plein. Nous réclamons les deux bits les plus bas de notre espace mantisse inutilisé comme une "étiquette de type" pour déterminer laquelle de ces trois valeurs singletons nous regardons. Les trois étiquettes de type sont définies comme ça :

^code tags (1 before, 2 after)

Notre représentation de `nil` est ainsi tous les bits requis pour définir notre représentation NaN silencieux avec les bits d'étiquette de type `nil` :

<img src="image/optimization/nil.png" alt="La représentation binaire de la valeur nil." />

En code, nous vérifions les bits comme ça :
^code nil-val (2 before, 1 after)

Nous faisons simplement un <span class="small-caps">OU</span> bit à bit des bits NaN silencieux et de l'étiquette de type, et ensuite faisons une petite danse de cast pour apprendre au compilateur C ce que nous voulons que ces bits signifient.

Puisque `nil` a seulement une représentation binaire unique, nous pouvons utiliser l'égalité sur uint64_t pour voir si une Value est `nil`.

<span name="equal"></span>

^code is-nil (2 before, 1 after)

Vous pouvez deviner comment nous définissons les valeurs `true` et `false`.

^code false-true-vals (2 before, 1 after)

Les bits ressemblent à ceci :

<img src="image/optimization/bools.png" alt="La représentation binaire des valeurs true et false." />

Pour convertir un booléen C en un Booléen Lox, nous comptons sur ces deux valeurs singletons et le bon vieil opérateur conditionnel.

^code bool-val (2 before, 1 after)

Il y a probablement une façon binaire plus intelligente de faire cela, mais mon intuition est que le compilateur peut en trouver une plus vite que je ne peux. Aller dans l'autre direction est plus simple.

^code as-bool (2 before, 1 after)

Puisque nous savons qu'il y a exactement deux représentations binaires Booléennes dans Lox -- contrairement à C où toute valeur non-zéro peut être considérée "vraie" -- si ce n'est pas `true`, ce doit être `false`. Cette macro suppose bien que vous l'appelez seulement sur une Value que vous savez _être_ un Booléen Lox. Pour vérifier cela, il y a une macro de plus.

^code is-bool (2 before, 1 after)

Cela semble un peu étrange. Une macro plus évidente ressemblerait à ceci :

```c
#define IS_BOOL(v) ((v) == TRUE_VAL || (v) == FALSE_VAL)
```

Malheureusement, ce n'est pas sûr. L'expansion mentionne `v` deux fois, ce qui signifie que si cette expression a de quelconques effets de bord, ils seront exécutés deux fois. Nous pourrions avoir la macro appelant une fonction séparée, mais, ugh, quelle corvée.

Au lieu de cela, nous faisons un <span class="small-caps">OU</span> bit à bit d'un 1 sur la valeur pour fusionner les deux seuls motifs de bits Booléens valides. Cela laisse trois états potentiels dans lesquels la valeur peut être :

1. Elle était `FALSE_VAL` et a maintenant été convertie en `TRUE_VAL`.

2. Elle était `TRUE_VAL` et le `| 1` n'a rien fait et c'est encore `TRUE_VAL`.

3. C'est quelque autre valeur, non-Booléenne.

À ce point, nous pouvons simplement comparer le résultat à `TRUE_VAL` pour voir si nous sommes dans les deux premiers états ou le troisième.

### Objets

Le dernier type de valeur est le plus dur. Contrairement aux valeurs singletons, il y a des milliards de valeurs de pointeur différentes que nous devons mettre en boîte à l'intérieur d'un NaN. Cela signifie que nous avons besoin à la fois de quelque sorte d'étiquette pour indiquer que ces NaNs particuliers _sont_ des pointeurs Obj, et de place pour les adresses elles-mêmes.

Les bits d'étiquette que nous avons utilisés pour les valeurs singletons sont dans la région où j'ai décidé de stocker le pointeur lui-même, donc nous ne pouvons pas facilement utiliser un <span name="ptr">bit</span> différent là pour indiquer que la valeur est une référence d'objet. Cependant, il y a un autre bit que nous n'utilisons pas. Puisque toutes nos valeurs NaN ne sont pas des nombres -- c'est juste là dans le nom -- le bit de signe n'est utilisé pour rien. Nous allons aller de l'avant et utiliser cela comme l'étiquette de type pour les objets. Si l'un de nos NaNs silencieux a son bit de signe mis, alors c'est un pointeur Obj. Sinon, ce doit être l'une des valeurs singletons précédentes.

<aside name="ptr">

Nous pourrions en fait utiliser les bits les plus bas pour stocker l'étiquette de type même quand la valeur est un pointeur Obj. C'est parce que les pointeurs Obj sont toujours alignés sur une frontière de 8 octets puisque Obj contient un champ 64 bits. Cela, en retour, implique que les trois bits les plus bas d'un pointeur Obj seront toujours zéro. Nous pourrions stocker ce que nous voulions là-dedans et juste le masquer avant de déréférencer le pointeur.

C'est une autre optimisation de représentation de valeur appelée **pointer tagging** (étiquetage de pointeur).

</aside>

Si le bit de signe est mis, alors les bits bas restants stockent le pointeur vers l'Obj :

<img src="image/optimization/obj.png" alt="Représentation binaire d'un Obj* stocké dans une Value." />

Pour convertir un pointeur Obj brut en une Value, nous prenons le pointeur et mettons tous les bits NaN silencieux et le bit de signe.

^code obj-val (1 before, 2 after)

Le pointeur lui-même est un plein 64 bits, et en <span name="safe">principe</span>, il pourrait ainsi chevaucher avec certains de ces bits NaN silencieux et signe. Mais en pratique, au moins sur les architectures que j'ai testées, tout au-dessus du 48ème bit dans un pointeur est toujours zéro. Il y a beaucoup de casting se passant ici, ce que j'ai trouvé nécessaire pour satisfaire certains des compilateurs C les plus difficiles, mais le résultat final est juste de coincer quelques bits ensemble.

<aside name="safe">

J'essaie de suivre la lettre de la loi quand il s'agit du code dans ce livre, donc ce paragraphe est douteux. Il vient un point lors de l'optimisation où vous poussez la limite de non seulement ce que la _spec dit_ que vous pouvez faire, mais ce qu'un vrai compilateur et puce vous laissent sortir avec.

Il y a des risques lors d'un pas en dehors de la spec, mais il y a des récompenses dans ce territoire sans loi aussi. C'est à vous de décider si les gains en valent la peine.

</aside>

Nous définissons le bit de signe comme ça :

^code sign-bit (2 before, 2 after)

Pour obtenir le pointeur Obj de retour, nous masquons simplement tous ces bits extra.

^code as-obj (1 before, 2 after)

Le tilde (`~`), si vous n'avez pas fait assez de manipulation de bits pour le rencontrer avant, est le <span class="small-caps">NON</span> bit à bit. Il bascule tous les uns et zéros dans son opérande. En masquant la valeur avec la négation binaire des bits NaN silencieux et signe, nous _effaçons_ ces bits et laissons les bits de pointeur rester.

Une dernière macro :

^code is-obj (1 before, 2 after)

Une Value stockant un pointeur Obj a son bit de signe mis, mais aussi n'importe quel nombre négatif. Pour dire si une Value est un pointeur Obj, nous avons besoin de vérifier qu'à la fois le bit de signe et tous les bits NaN silencieux sont mis. C'est similaire à comment nous détectons le type des valeurs singletons, sauf que cette fois nous utilisons le bit de signe comme l'étiquette.

### Fonctions de valeur

Le reste de la VM passe habituellement par les macros lors du travail avec les Values, donc nous avons presque fini. Cependant, il y a une couple de fonctions dans le module "value" qui jettent un coup d'œil à l'intérieur de la boîte autrement noire de Value et travaillent avec son encodage directement. Nous avons besoin de fixer celles-ci aussi.

La première est `printValue()`. Elle a un code séparé pour chaque type de valeur. Nous n'avons plus d'énumération de type explicite sur laquelle nous pouvons switcher, donc au lieu de cela nous utilisons une série de tests de type pour gérer chaque sorte de valeur.

^code print-value (1 before, 1 after)

C'est techniquement un tout petit peu plus lent qu'un switch, mais comparé au surcoût d'écrire réellement vers un flux, c'est négligeable.

Nous supportons encore la représentation union étiquetée originale, donc nous gardons le vieux code et l'entourons dans la section conditionnelle `#else`.

^code end-print-value (1 before, 1 after)

L'autre opération est de tester deux valeurs pour l'égalité.

^code values-equal (1 before, 1 after)

Cela ne devient pas beaucoup plus simple que ça ! Si les deux représentations binaires sont identiques, les valeurs sont égales. Cela fait la bonne chose pour les valeurs singletons puisque chacune a une représentation binaire unique et elles sont seulement égales à elles-mêmes. Cela fait aussi la bonne chose pour les pointeurs Obj, puisque les objets utilisent l'identité pour l'égalité -- deux références Obj sont égales seulement si elles pointent vers l'objet exactement identique.

C'est _surtout_ correct pour les nombres aussi. La plupart des nombres à virgule flottante avec différentes représentations binaires sont des valeurs numériques distinctes. Hélas, IEEE 754 contient un nid-de-poule pour nous faire trébucher. Pour des raisons qui ne sont pas entièrement claires pour moi, la spec mandate que les valeurs NaN ne sont _pas_ égales à _elles-mêmes_. Ce n'est pas un problème pour les NaNs silencieux spéciaux que nous utilisons pour nos propres buts. Mais il est possible de produire un "vrai" NaN arithmétique dans Lox, et si nous voulons implémenter correctement les nombres IEEE 754, alors la valeur résultante n'est pas supposée être égale à elle-même. Plus concrètement :

```lox
var nan = 0/0;
print nan == nan;
```

IEEE 754 dit que ce programme est supposé afficher "false". Il fait la bonne chose avec notre vieille représentation union étiquetée parce que le cas `VAL_NUMBER` applique `==` à deux valeurs que le compilateur C sait être des doubles. Ainsi le compilateur génère la bonne instruction CPU pour effectuer une égalité virgule flottante IEEE.

Notre nouvelle représentation brise cela en définissant Value pour être un uint64*t. Si nous voulons être \_pleinement* conformes avec IEEE 754, nous avons besoin de gérer ce cas.

^code nan-equality (1 before, 1 after)

Je sais, c'est bizarre. Et il y a un coût de performance à faire ce test de type chaque fois que nous vérifions deux valeurs Lox pour l'égalité. Si nous sommes prêts à sacrifier un peu de <span name="java">compatibilité</span> -- qui se soucie _vraiment_ si NaN n'est pas égal à lui-même ? -- nous pourrions laisser cela de côté. Je laisserai à vous de décider à quel point vous voulez être pédant.

<aside name="java">

En fait, jlox se trompe sur l'égalité NaN. Java fait la bonne chose quand vous comparez des doubles primitifs utilisant `==`, mais pas si vous mettez en boîte ceux-ci vers Double ou Object et les comparez utilisant `equals()`, ce qui est comment jlox implémente l'égalité.

</aside>

Finalement, nous fermons la section de compilation conditionnelle autour de la vieille implémentation.

^code end-values-equal (1 before, 1 after)

Et c'est ça. Cette optimisation est complète, comme l'est notre machine virtuelle clox. C'était la dernière ligne de nouveau code dans le livre.

### Évaluer la performance

Le code est fait, mais nous avons encore besoin de comprendre si nous avons réellement rendu quoi que ce soit meilleur avec ces changements. Évaluer une optimisation comme celle-ci est très différent de la précédente. Là, nous avions un point chaud clair visible dans le profileur. Nous avons fixé cette partie du code et pouvions instantanément voir le point chaud devenir plus rapide.

Les effets de changer la représentation de valeur sont plus diffus. Les macros sont expansées sur place où qu'elles soient utilisées, donc les changements de performance sont étalés à travers la base de code d'une manière qui est dure pour beaucoup de profileurs de bien traquer, spécialement dans une build <span name="opt">optimisée</span>.

<aside name="opt">

Lors du travail de profilage, vous voulez presque toujours profiler une build "release" optimisée de votre programme puisque cela reflète l'histoire de performance que vos utilisateurs finaux expérimentent. Les optimisations du compilateur, comme l'inlining, peuvent dramatiquement affecter quelles parties du code sont des points chauds de performance. Optimiser à la main une build debug risque de vous envoyer "fixer" des problèmes que le compilateur optimisant résoudra déjà pour vous.

Assurez-vous que vous ne benchmarkez et optimisez pas accidentellement votre build debug. Je semble faire cette erreur au moins une fois par an.

</aside>

Nous ne pouvons aussi pas facilement _raisonner_ sur les effets de notre changement. Nous avons rendu les valeurs plus petites, ce qui réduit les miss de cache tout à travers la VM. Mais l'effet de performance réel monde-réel de ce changement est hautement dépendant de l'utilisation mémoire du programme Lox étant couru. Un minuscule microbenchmark Lox peut ne pas avoir assez de valeurs dispersées autour en mémoire pour que l'effet soit notable, et même des choses comme les adresses distribuées à nous par l'allocateur de mémoire C peuvent impacter les résultats.

Si nous avons fait notre travail correctement, essentiellement tout devient un peu plus rapide, spécialement sur des programmes Lox plus larges, plus complexes. Mais il est possible que les opérations binaires extra que nous faisons lors du NaN-boxing des valeurs annulent les gains de la meilleure utilisation mémoire. Faire du travail de performance comme cela est énervant parce que vous ne pouvez pas facilement _prouver_ que vous avez rendu la VM meilleure. Vous ne pouvez pas pointer un microbenchmark unique chirurgicalement ciblé et dire, "Là, tu vois ?"

Au lieu de cela, ce dont nous avons vraiment besoin est une _suite_ de plus larges benchmarks. Idéalement, ils seraient distillés d'applications du monde réel -- pas qu'une telle chose existe pour un langage jouet comme Lox. Alors nous pouvons mesurer les changements de performance agrégés à travers tous ceux-ci. J'ai fait de mon mieux pour bricoler une poignée de programmes Lox plus larges. Sur ma machine, la nouvelle représentation de valeur semble rendre tout grossièrement 10% plus rapide à travers le tableau.

Ce n'est pas une énorme amélioration, spécialement comparé à l'effet profond de rendre les recherches de table de hachage plus rapides. J'ai ajouté cette optimisation en grande partie parce que c'est un bon exemple d'un certain _genre_ de travail de performance que vous pouvez expérimenter, et honnêtement, parce que je pense que c'est techniquement vraiment cool. Cela pourrait ne pas être la première chose que j'attraperais si j'essayais sérieusement de rendre clox plus rapide. Il y a probablement d'autres fruits plus bas.

Mais, si vous vous trouvez travaillant sur un programme où toutes les victoires faciles ont été prises, alors à un certain point vous pouvez vouloir penser à régler votre représentation de valeur. J'espère que ce chapitre a brillé une lumière sur certaines des options que vous avez dans cette zone.

## Où aller ensuite

Nous arrêterons ici avec le langage Lox et nos deux interpréteurs. Nous pourrions bricoler dessus pour toujours, ajoutant de nouvelles fonctionnalités de langage et des améliorations de vitesse intelligentes. Mais, pour ce livre, je pense que nous avons atteint un endroit naturel pour appeler notre travail complet. Je ne ressasserai pas tout ce que nous avons appris dans les nombreuses pages passées. Vous étiez là avec moi et vous vous souvenez. Au lieu de cela, j'aimerais prendre une minute pour parler de où vous pourriez aller d'ici. Quelle est la prochaine étape dans votre voyage de langage de programmation ?

La plupart d'entre vous ne passerez probablement pas une partie significative de votre carrière travaillant dans les compilateurs ou interpréteurs. C'est une tranche assez petite de la tarte académique de l'informatique, et un segment encore plus petit de l'ingénierie logicielle dans l'industrie. C'est OK. Même si vous ne travaillez jamais sur un compilateur encore dans votre vie, vous en _utiliserez_ certainement un, et j'espère que ce livre vous a équipé avec une meilleure compréhension de comment les langages de programmation que vous utilisez sont conçus et implémentés.

Vous avez aussi appris une poignée de structures de données fondamentales importantes et obtenu de la pratique faisant du travail de profilage et d'optimisation bas niveau. Ce genre d'expertise est utile peu importe quel domaine vous programmez.

J'espère aussi que je vous ai donné une nouvelle façon de <span name="domain">regarder</span> et résoudre les problèmes. Même si vous ne travaillez jamais sur un langage encore, vous pouvez être surpris de découvrir combien de problèmes de programmation peuvent être vus comme _type_-langage. Peut-être ce générateur de rapport que vous avez besoin d'écrire peut être modélisé comme une série d'"instructions" basées sur pile que le générateur "exécute". Cette interface utilisateur que vous avez besoin de rendre ressemble terriblement à traverser un AST.

<aside name="domain">

Cela va pour d'autres domaines aussi. Je ne pense pas qu'il y ait un seul sujet que j'ai appris en programmation -- ou même en dehors de la programmation -- que je n'ai pas fini par trouver utile dans d'autres zones. Un de mes aspects favoris de l'ingénierie logicielle est combien elle récompense ceux avec des intérêts éclectiques.

</aside>

Si vous voulez aller plus loin dans le terrier de lapin des langages de programmation, voici quelques suggestions pour quelles branches dans le tunnel explorer :

- Notre compilateur bytecode simple, à une passe nous a poussés vers surtout de l'optimisation à l'exécution. Dans une implémentation de langage mature, l'optimisation à la compilation est généralement plus importante, et le champ des optimisations de compilateur est incroyablement riche. Attrapez un livre de <span name="cooper">compilateurs</span> classique, et rebatissez le front end de clox ou jlox pour être un pipeline de compilation sophistiqué avec quelques représentations intermédiaires intéressantes et passes d'optimisation.

    Le typage dynamique placera quelques restrictions sur jusqu'où vous pouvez aller, mais il y a encore beaucoup que vous pouvez faire. Ou peut-être vous voulez faire un grand saut et ajouter des types statiques et un vérificateur de type à Lox. Cela donnera certainement à votre front end beaucoup plus à mâcher.

      <aside name="cooper">

    J'aime _Engineering a Compiler_ de Cooper et Torczon pour cela. Les livres _Modern Compiler Implementation_ d'Appel sont aussi bien regardés.

      </aside>

- Dans ce livre, je vise à être correct, mais pas particulièrement rigoureux. Mon but est surtout de vous donner une _intuition_ et une sensation pour faire du travail de langage. Si vous aimez plus de précision, alors le monde entier de l'académie des langages de programmation vous attend. Les langages et compilateurs ont été étudiés formellement depuis avant que nous ayons même des ordinateurs, donc il n'y a pas de pénurie de livres et papiers sur la théorie d'analyseur, les systèmes de type, la sémantique, et la logique formelle. Descendre ce chemin vous apprendra aussi comment lire des papiers CS, ce qui est une compétence précieuse en son propre droit.

- Ou, si vous appréciez juste vraiment hacker sur et faire des langages, vous pouvez prendre Lox et le transformer en votre propre <span name="license">jouet</span>. Changez la syntaxe pour quelque chose qui ravit votre œil. Ajoutez des fonctionnalités manquantes ou enlevez celles que vous n'aimez pas. Coincez de nouvelles optimisations là-dedans.

      <aside name="license">

    Le _texte_ de ce livre est sous copyright à moi, mais le _code_ et les implémentations de jlox et clox utilisent la très permissive [Licence MIT][mit license]. Vous êtes plus que bienvenus de [prendre l'un ou l'autre de ces interpréteurs][source] et faire tout ce que vous voulez avec eux. Allez en ville.

    Si vous faites des changements significatifs au langage, ce serait bon de changer aussi le nom, surtout pour éviter de rendre confus les gens à propos de ce que le nom "Lox" représente.

      </aside>

    Éventuellement vous pouvez arriver à un point où vous avez quelque chose que vous pensez que d'autres pourraient utiliser aussi. Cela vous amène dans le monde très distinct de la _popularité_ des langages de programmation. Attendez-vous à passer une tonne de temps à écrire de la documentation, des programmes d'exemple, des outils, et des bibliothèques utiles. Le champ est bondé avec des langages rivalisant pour des utilisateurs. Pour prospérer dans cet espace vous aurez à mettre votre chapeau de marketing et _vendre_. Tout le monde n'apprécie pas ce genre de travail face au public, mais si vous le faites, cela peut être incroyablement gratifiant de voir des gens utiliser votre langage pour s'exprimer eux-mêmes.

Ou peut-être ce livre a satisfait votre envie et vous arrêterez ici. Peu importe le chemin que vous prenez, ou ne prenez pas, il y a une leçon que j'espère loger dans votre cœur. Comme je l'étais, vous pouvez avoir été initialement intimidés par les langages de programmation. Mais dans ces chapitres, vous avez vu que même du matériel vraiment difficile peut être taclé par nous mortels si nous mettons nos mains dans la saleté et le prenons une étape à la fois. Si vous pouvez gérer les compilateurs et interpréteurs, vous pouvez faire tout ce à quoi vous mettez votre esprit.

[mit license]: https://fr.wikipedia.org/wiki/Licence_MIT
[source]: https://github.com/munificent/craftinginterpreters

<div class="challenges">

## Défis

Assigner des devoirs le dernier jour d'école semble cruel mais si vous voulez vraiment quelque chose à faire durant vos vacances d'été :

1.  Démarrez votre profileur, courez une paire de benchmarks, et cherchez d'autres points chauds dans la VM. Voyez-vous quelque chose dans le runtime que vous pouvez améliorer ?

2.  Beaucoup de chaînes dans les programmes utilisateur du monde réel sont petites, souvent seulement un caractère ou deux. C'est moins une préoccupation dans clox parce que nous internons les chaînes, mais la plupart des VMs ne le font pas. Pour celles qui ne le font pas, allouer sur le tas un minuscule tableau de caractères pour chacune de ces petites chaînes et ensuite représenter la valeur comme un pointeur vers ce tableau est gaspilleur. Souvent, le pointeur est plus grand que les caractères de la chaîne. Un truc classique est d'avoir une représentation de valeur séparée pour les petites chaînes qui stocke les caractères en ligne dans la valeur.

    Commençant depuis la représentation union étiquetée originale de clox, implémentez cette optimisation. Écrivez un couple de benchmarks pertinents et voyez si cela aide.

3.  Réfléchissez en arrière sur votre expérience avec ce livre. Quelles parties de celui-ci ont bien marché pour vous ? Quoi non ? Était-ce plus facile pour vous d'apprendre de bas en haut ou de haut en bas ? Les illustrations aidaient-elles ou distrayaient-elles ? Les analogies clarifiaient-elles ou rendaient-elles confus ?

    Plus vous comprenez votre style d'apprentissage personnel, plus efficacement vous pouvez uploader la connaissance dans votre tête. Vous pouvez spécifiquement cibler le matériel qui vous enseigne de la façon dont vous apprenez le mieux.

</div>
