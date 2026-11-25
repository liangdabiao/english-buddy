import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const toolDir = dirname(fileURLToPath(import.meta.url));
const projectDir = resolve(toolDir, '..');
const referenceDir = resolve(projectDir, '..', '..', 'magic-english-buddy-main');
const dataUrl = pathToFileURL(resolve(referenceDir, 'src/data/index.ts')).href;
const mapUrl = pathToFileURL(resolve(referenceDir, 'src/data/maps/l1-forest.ts')).href;
const { levelDataMap } = await import(dataUrl);
const { l1StoryTitles } = await import(mapUrl);
const manifest = JSON.parse(readFileSync(resolve(referenceDir, 'src/data/audio/manifest.json'), 'utf8'));
const level = levelDataMap[1];

const paragraphClips = new Map();
for (const paragraphs of Object.values(manifest.stories)) {
  paragraphs.forEach((text, index) => paragraphClips.set(text, manifest.clips[text] ?? manifest.clips[paragraphs[index]]));
}

const stories = level.stories
  .map((story) => {
    const meta = l1StoryTitles[story.id] ?? { emoji: '📖' };
    const content = story.content.map((paragraph) => {
      const clip = manifest.clips[paragraph.text] ?? paragraphClips.get(paragraph.text);
      if (!clip) throw new Error(`Missing bundled audio for ${story.id}: ${paragraph.text}`);
      return {
        id: paragraph.paragraphId,
        text: paragraph.text,
        translation: paragraph.translation,
        audioFile: clip.file,
        duration: clip.duration,
        words: clip.words.map((word) => ({
          word: word.word,
          start: word.start,
          end: word.end,
          index: word.index,
        })),
      };
    });
    return {
      id: story.id,
      title: story.title,
      titleCn: story.titleCn,
      emoji: meta.emoji,
      content,
      quiz: story.quiz,
      rewards: story.rewards,
    };
  });

const storyIds = new Set(stories.map((story) => story.id));
const courses = level.getMapNodes()
  .filter((node) => storyIds.has(node.storyId))
  .map((node) => ({
    id: node.id,
    storyId: node.storyId,
    type: node.type,
    title: node.title,
    titleCn: node.titleCn,
    emoji: node.emoji,
    rewards: node.rewards,
  }));

const emojis = new Set();
for (const story of stories) {
  emojis.add(story.emoji);
  for (const quiz of story.quiz) {
    for (const option of quiz.options ?? []) {
      if (option.image && /\p{Extended_Pictographic}/u.test(option.image)) emojis.add(option.image);
    }
  }
}
for (const entry of level.dictionary) {
  if (entry.emoji && /\p{Extended_Pictographic}/u.test(entry.emoji)) emojis.add(entry.emoji);
}

const content = {
  version: 1,
  region: {
    id: level.regionConfig.id,
    name: level.regionConfig.name,
    nameCn: level.regionConfig.nameCn,
  },
  courses,
  stories,
  dictionary: level.dictionary,
  emojis: [...emojis],
  source: {
    project: 'magic-english-buddy-main',
    level: 1,
    stories: stories.length,
    dictionary: level.dictionary.length,
    audioClips: new Set(stories.flatMap((story) => story.content.map((paragraph) => paragraph.audioFile))).size,
  },
};

mkdirSync(resolve(projectDir, 'data'), { recursive: true });
mkdirSync(resolve(projectDir, 'assets/audio'), { recursive: true });
writeFileSync(resolve(projectDir, 'data/content.json'), JSON.stringify(content));
for (const file of new Set(stories.flatMap((story) => story.content.map((paragraph) => paragraph.audioFile)))) {
  copyFileSync(resolve(referenceDir, 'public/audio', file), resolve(projectDir, 'assets/audio', file));
}
console.log(JSON.stringify(content.source, null, 2));
