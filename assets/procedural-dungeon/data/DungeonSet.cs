using System.Collections.Generic;
using Assets.Scripts.Generators.Dungeon.Elements;
using Assets.Scripts.Utils;
using UnityEngine;

namespace Assets.Meta.Sets
{
    //TODO - Transfer to Scripts.
    [CreateAssetMenu(fileName = "DungeonSet", menuName = "DungeonSet", order = 2)]
    public class DungeonSet : ScriptableObject
    {
        public string setName = "";
        public List<Element> spawnTemplates = new();
        public List<Element> roomTemplates = new();
        public List<Element> hallwayTemplates = new();
        public List<Element> closingTemplates = new();       

        private List<Element> openElements;
        private List<Element> openTwoWayElements;
        private List<Element> hallwayElements;
        private List<Element> closingElements;

        public void InitTemplateElements()
        {
            openElements = GetTemplateElements(roomTemplates);
            openTwoWayElements = GetTemplateElements(roomTemplates);
            hallwayElements = GetTemplateElements(hallwayTemplates);
            closingElements = GetTemplateElements(closingTemplates);
        }

        protected static List<Element> GetTemplateElements(List<Element> templates)
        {
            int templatesCount = templates.Count;
            List<Element> elements = new(templatesCount);
            for (int i = 0; i < templatesCount; i++)
            {
                Element element = templates[i];
                elements.Add(element);
            }
            
            return elements;
        }

        public Dictionary<string, List<GameObject>> GetElementPools(Dictionary<string, List<GameObject>> pools)
        {
            InitTemplatePool(roomTemplates, pools);
            InitTemplatePool(hallwayTemplates, pools);
            InitTemplatePool(closingTemplates, pools);

            return pools;
        }

        protected static void InitTemplatePool(List<Element> templates, Dictionary<string, List<GameObject>> pools)
        {
            int templatesCount = templates.Count;
            for (int i = 0; i < templatesCount; i++)
            {
                Element element = templates[i];
                pools[element.ID] = new List<GameObject>();
            }
        }

        // MOAR REFACTOR!! GENERALIZE! GENERALIZE!    

        public Element[] GetAllHallwayElementsShuffled(DRandom random)
        {
            hallwayElements.Shuffle(random.random);
            return hallwayElements.ToArray();
        }

        public Element[] GetAllOpenElementsShuffled(DRandom random)
        {
            openElements.Shuffle(random.random);
            return openElements.ToArray();
        }

        public Element[] GetAllTwoWayOpenElementsShuffled(DRandom random)
        {
            openTwoWayElements.Shuffle(random.random);
            return openTwoWayElements.ToArray();
        }

        public Element[] GetAllClosingElementsShuffled(DRandom random)
        {
            closingElements.Shuffle(random.random);
            return closingElements.ToArray();
        }
        //
    }
}