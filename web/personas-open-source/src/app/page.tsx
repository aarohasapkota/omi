'use client';

// ------------------------------------------------------------------------------------
// TEMPORARY: Force a fixed UID for end‑to‑end testing in prod/staging environments.
//            Comment out or delete the following line (and its usages) once testing is
//            finished and real Firebase anonymous/authenticated UIDs should be used.
// export const TEST_UID = "kiTPO8XwMlOpFpb4x1diyMg213j2"; // <-- commented after tests
// ------------------------------------------------------------------------------------

import { SetStateAction, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { db } from '@/lib/firebase';
import {
  collection,
  addDoc,
  query,
  where,
  getDocs,
  orderBy,
  startAfter,
  limit,
  doc,
  setDoc,
  or,
} from 'firebase/firestore';
import { toast } from 'sonner';
import { Mixpanel } from '@/lib/mixpanel';
import { useInView } from 'react-intersection-observer';
import { ulid } from 'ulid';
import { auth } from '@/lib/firebase';
import { Header } from '@/components/Header';
import { InputArea } from '@/components/InputArea';
import { ChatbotList } from '@/components/ChatbotList';
import { Footer } from '@/components/Footer';
import { Chatbot, TwitterProfile, LinkedinProfile } from '@/types/profiles';
import { PreorderBanner } from '@/components/shared/PreorderBanner';
import { signInAnonymously, onAuthStateChanged, User } from 'firebase/auth';

// Helper function to detect mobile devices (basic check)
const isMobileDevice = (): boolean => {
  if (typeof window === 'undefined') return false;
  // Basic check using userAgent - consider a library like 'react-device-detect' for more robustness
  return /Mobi|Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
};

const formatTwitterAvatarUrl = (url: string): string => {
  if (!url) return '/omi-avatar.svg';
  let formattedUrl = url.replace('http://', 'https://');
  formattedUrl = formattedUrl.replace('_normal', '');
  if (formattedUrl.includes('pbs.twimg.com')) {
    formattedUrl = formattedUrl.replace('/profile_images/', '/profile_images/');
  }
  return formattedUrl;
};

const formatDate = (dateString: string): string => {
  const date = new Date(dateString);
  return new Intl.DateTimeFormat('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    timeZoneName: 'short',
    hour12: false,
  })
    .format(date)
    .replace(',', ' at');
};

const fetchTwitterTimeline = async (screenname: string) => {
  try {
    const response = await fetch(
      `https://${process.env.NEXT_PUBLIC_RAPIDAPI_HOST}/timeline.php?screenname=${screenname}`,
      {
        headers: {
          'x-rapidapi-key': process.env.NEXT_PUBLIC_RAPIDAPI_KEY!,
          'x-rapidapi-host': process.env.NEXT_PUBLIC_RAPIDAPI_HOST!,
        },
      },
    );

    const data = await response.json();

    const tweets = [];
    if (data.timeline) {
      for (const tweet of Object.values(data.timeline)) {
        const tweetData = tweet as any;
        if (tweets.length >= 30) break;
        if (tweetData.text && !tweetData.text.startsWith('RT @')) {
          tweets.push(tweetData.text);
        }
      }
    }

    return tweets;
  } catch (error) {
    console.error('Error fetching timeline:', error);
    return [];
  }
};

const PlatformSelectionModal = ({
  isOpen,
  onClose,
  platforms,
  onSelect,
  mode,
}: {
  isOpen: boolean;
  onClose: () => void;
  platforms: { twitter: boolean; linkedin: boolean };
  onSelect: (platform: 'twitter' | 'linkedin') => void;
  mode: 'create' | 'add';
}) => (
  <div
    className={`fixed inset-0 flex items-center justify-center bg-black bg-opacity-50 ${
      isOpen ? '' : 'hidden'
    }`}
  >
    <div className="w-full max-w-md rounded-lg bg-zinc-900 p-6">
      <h2 className="mb-4 text-xl font-bold">
        {mode === 'create' ? 'Select Platform' : 'Add Additional Profile'}
      </h2>
      <p className="mb-6 text-zinc-400">
        {mode === 'create'
          ? 'This handle is available on multiple platforms. Which one would you like to use?'
          : 'We found an additional profile for this handle. Would you like to add it?'}
      </p>
      <div className="space-y-4">
        {platforms.twitter && (
          <button
            onClick={() => onSelect('twitter')}
            className="flex w-full items-center justify-center gap-2 rounded-lg bg-blue-600 py-2 text-white hover:bg-blue-700"
          >
            Twitter Profile
          </button>
        )}
        {platforms.linkedin && (
          <button
            onClick={() => onSelect('linkedin')}
            className="flex w-full items-center justify-center gap-2 rounded-lg bg-[#0077b5] py-2 text-white hover:bg-[#006399]"
          >
            LinkedIn Profile
          </button>
        )}
        <button onClick={onClose} className="w-full text-zinc-400 hover:text-white">
          Cancel
        </button>
      </div>
    </div>
  </div>
);

export default function HomePage() {
  const router = useRouter();
  const [chatbots, setChatbots] = useState<Chatbot[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [isCreating, setIsCreating] = useState(false);
  const [hasMore, setHasMore] = useState(true);
  const [lastDoc, setLastDoc] = useState<any>(null);
  const { ref, inView } = useInView();
  const [handle, setHandle] = useState('');
  //modal state variables
  const [showPlatformModal, setShowPlatformModal] = useState(false);
  const [pendingCleanHandle, setPendingCleanHandle] = useState<string | null>(null);
  const [availablePlatforms] = useState({ twitter: true, linkedin: true });
  const [platformSelectionMode] = useState<'create' | 'add'>('create');
  const [currentUserUid, setCurrentUserUid] = useState<string | null>(null);
  const [authInitialized, setAuthInitialized] = useState<boolean>(false);
  const [isIntegrating, setIsIntegrating] = useState(false);

  // ----------------------------------------------------------------------------------
  // Helper: open ChatGPT workspace - NOW WITH MOBILE HANDLING
  // Comment or delete after tests together with TEST_UID declarations.
  const openChatGPTWithUid = (uid: string) => {
    const isMobile = isMobileDevice();
    const baseChatGPTUrl =
      'https://chatgpt.com/g/g-67e2772d0af081919a5baddf4a12aacf-omigpt';

    console.log(`[openChatGPTWithUid] Detected mobile: ${isMobile}`);

    if (isMobile) {
      // Mobile flow: Copy UID, show toast, redirect after delay
      navigator.clipboard
        .writeText(uid)
        .then(() => {
          console.log('[openChatGPTWithUid] UID copied to clipboard for mobile.');
          toast.success('UID copied! Paste it into ChatGPT.', {
            duration: 3000, // Show toast for 3 seconds
          });
          // Redirect after toast duration
          setTimeout(() => {
            console.log(
              `[openChatGPTWithUid] Redirecting mobile to base URL: ${baseChatGPTUrl}`,
            );
            window.location.href = baseChatGPTUrl;
          }, 3000);
        })
        .catch((err) => {
          console.error('[openChatGPTWithUid] Failed to copy UID to clipboard:', err);
          // Show UID in the error toast for manual copying
          toast.error(`Redirecting to integration partner`, {
            duration: 5000, // Give a bit more time to see/copy
          });
          // Still redirect after a delay, allowing time for manual copy
          setTimeout(() => {
            console.log(
              `[openChatGPTWithUid] Redirecting mobile (after copy fail) to base URL: ${baseChatGPTUrl}`,
            );
            window.location.href = baseChatGPTUrl;
          }, 5000); // Increased delay
        });
    } else {
      // Desktop flow: Redirect immediately with UID parameter
      const redirectUrl = `${baseChatGPTUrl}?prompt=uid=${encodeURIComponent(uid)}`;
      console.log(`[openChatGPTWithUid] Redirecting desktop to: ${redirectUrl}`);
      window.location.href = redirectUrl;
    }
  };
  // ----------------------------------------------------------------------------------

  // Effect to observe Firebase Auth state and store the UID
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user: User | null) => {
      if (user) {
        console.log('[Auth State] User found:', user.uid);
        setCurrentUserUid(user.uid);
      } else {
        console.log('[Auth State] No user found.');
        setCurrentUserUid(null);
      }
      setAuthInitialized(true); // Mark auth as initialized
    });

    // Cleanup subscription on unmount
    return () => unsubscribe();
  }, []); // Empty dependency array ensures this runs only once on mount

  // Helper function to reliably get UID, creating anonymous if needed
  const getUid = async (): Promise<string | null> => {
    if (!authInitialized) {
      // Auth hasn't initialized yet, wait briefly or handle differently?
      // For now, try direct check + anonymous creation as fallback
      console.warn('[getUid] Auth not initialized, attempting direct check/creation.');
    }

    // 1. Check state first (set by onAuthStateChanged)
    if (currentUserUid) {
      console.log('[getUid] Using UID from state:', currentUserUid);
      return currentUserUid;
    }

    // 2. Check current auth object directly (might be null if not initialized)
    if (auth.currentUser) {
      console.log('[getUid] Using UID from auth.currentUser:', auth.currentUser.uid);
      setCurrentUserUid(auth.currentUser.uid); // Update state
      return auth.currentUser.uid;
    }

    // 3. If no user found, create an anonymous one
    console.log('[getUid] No user found, attempting anonymous sign-in...');
    try {
      const result = await signInAnonymously(auth);
      const newUid = result.user.uid;
      console.log('[getUid] Signed in anonymously, new UID:', newUid);
      setCurrentUserUid(newUid); // Update state
      return newUid;
    } catch (err) {
      console.error('[getUid] Anonymous sign-in failed:', err);
      toast.error('Failed to initialize user session.');
      return null; // Indicate failure
    }
  };

  // Handle profile parameter on mount
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const profileParam = params.get('profile');

    if (profileParam) {
      const cleanHandle = extractHandle(profileParam);
      setHandle(cleanHandle);
      handleCreatePersona(cleanHandle);
    }
  }, []);

  const handleInputChange = (e: { target: { value: SetStateAction<string> } }) => {
    setHandle(e.target.value);
  };

  //function to retrieve the document id from Firestore.
  const getProfileDocId = async (
    cleanHandle: string,
    category: 'twitter' | 'linkedin',
  ): Promise<string | null> => {
    const q = query(
      collection(db, 'plugins_data'),
      where('username', '==', cleanHandle.toLowerCase()),
      where('connected_accounts', 'array-contains', category),
    );

    const q2 = query(
      collection(db, 'plugins_data'),
      where('username', '==', cleanHandle.toLowerCase()),
      where('category', '==', category),
    );

    const [querySnapshot1, querySnapshot2] = await Promise.all([getDocs(q), getDocs(q2)]);

    if (!querySnapshot1.empty || !querySnapshot2.empty) {
      const doc = querySnapshot1.empty ? querySnapshot2.docs[0] : querySnapshot1.docs[0];
      return doc.id;
    }
    return null;
  };

  //helper functions to extract handles from specific platforms
  const extractTwitterHandle = (input: string): string | null => {
    const trimmedInput = input.trim();
    const twitterMatch = trimmedInput.match(/x\.com\/(?:#!\/)?@?([^/?]+)/i);
    if (twitterMatch && twitterMatch[1]) {
      return twitterMatch[1];
    }
    return null;
  };

  const extractLinkedinHandle = (input: string): string | null => {
    const trimmedInput = input.trim();
    const linkedinMatch = trimmedInput.match(/linkedin\.com\/in\/([^/?]+)/i);
    if (linkedinMatch && linkedinMatch[1]) {
      return linkedinMatch[1];
    }
    return null;
  };

  //helper function to extract a handle from a URL or raw handle input.
  const extractHandle = (input: string): string => {
    // Try platform-specific extractors first
    const twitterHandle = extractTwitterHandle(input);
    if (twitterHandle) return twitterHandle;

    const linkedinHandle = extractLinkedinHandle(input);
    if (linkedinHandle) return linkedinHandle;

    // If not a URL, remove leading '@' if present
    const trimmedInput = input.trim();
    return trimmedInput.startsWith('@') ? trimmedInput.substring(1) : trimmedInput;
  };

  // Helper functions to determine input type
  const isTwitterInput = (input: string): boolean => {
    return /x\.com\//i.test(input.trim());
  };

  const isLinkedinInput = (input: string): boolean => {
    return /linkedin\.com\//i.test(input.trim());
  };

  const checkExistingProfile = async (
    cleanHandle: string,
    category: 'twitter' | 'linkedin',
  ): Promise<string | null> => {
    const q = query(
      collection(db, 'plugins_data'),
      where('username', '==', cleanHandle.toLowerCase()),
      where('connected_accounts', 'array-contains', category),
    );

    const q2 = query(
      collection(db, 'plugins_data'),
      where('username', '==', cleanHandle.toLowerCase()),
      where('category', '==', category),
    );

    const [querySnapshot1, querySnapshot2] = await Promise.all([getDocs(q), getDocs(q2)]);

    if (!querySnapshot1.empty || !querySnapshot2.empty) {
      const doc = querySnapshot1.empty ? querySnapshot2.docs[0] : querySnapshot1.docs[0];
      return doc.id;
    }
    return null;
  };

  // Modified handleCreatePersona to accept an optional handle parameter
  const handleCreatePersona = async (inputHandle?: string) => {
    if (isCreating) return;

    const handleToUse = (inputHandle || handle || '').toString();
    if (!handleToUse || handleToUse.trim() === '') {
      toast.error('Please enter a handle');
      return;
    }

    // Track the click event in Mixpanel
    Mixpanel.track('Create Persona Clicked', {
      input: handleToUse,
      timestamp: new Date().toISOString(),
    });

    try {
      setIsCreating(true);
      const cleanHandle = extractHandle(handleToUse);
      let twitterResult = false;
      let linkedinResult = false;
      let existingId: string | null = null;

      // Check if it's a specific platform URL
      if (isTwitterInput(handleToUse)) {
        existingId = await checkExistingProfile(cleanHandle, 'twitter');
        if (existingId) {
          // Existing persona found – open ChatGPT directly
          const uid = await getUid();
          if (uid) openChatGPTWithUid(uid);
          else toast.error('Could not get user ID to redirect.');
          return;
        }
        twitterResult = await fetchTwitterProfile(cleanHandle);
        if (twitterResult) {
          return;
        }
      } else if (isLinkedinInput(handleToUse)) {
        existingId = await checkExistingProfile(cleanHandle, 'linkedin');
        if (existingId) {
          // Existing persona found – open ChatGPT directly
          const uid = await getUid();
          if (uid) openChatGPTWithUid(uid);
          else toast.error('Could not get user ID to redirect.');
          return;
        }
        linkedinResult = await fetchLinkedinProfile(cleanHandle);
        if (linkedinResult) {
          return;
        }
      } else {
        // Try Twitter first
        twitterResult = await fetchTwitterProfile(cleanHandle);
        if (twitterResult) {
          return;
        }

        // Then try LinkedIn
        linkedinResult = await fetchLinkedinProfile(cleanHandle);
        if (linkedinResult) {
          return;
        }
      }

      if (!twitterResult && !linkedinResult) {
        toast.error('No profiles found for the given handle.');
      }
    } catch (error) {
      console.error('Error in handleCreatePersona:', error);
      toast.error('Failed to create or find the persona.');
    } finally {
      setIsCreating(false);
    }
  };

  //handler for modal selection.
  const handlePlatformSelect = async (platform: 'twitter' | 'linkedin') => {
    if (pendingCleanHandle) {
      const existingId = await checkExistingProfile(pendingCleanHandle, platform);
      if (existingId) {
        toast.success('Profile already exists, redirecting...');
        const uid = await getUid();
        if (uid) openChatGPTWithUid(uid);
        else toast.error('Could not get user ID to redirect.');
      } else {
        toast.error('No profiles found for the given handle.');
      }
    }
    setShowPlatformModal(false);
    setPendingCleanHandle(null);
  };

  const BOTS_PER_PAGE = 50;

  useEffect(() => {
    // Identify the user first
    Mixpanel.identify();

    // Then track the page view
    Mixpanel.track('Page View', {
      page: 'Home',
      url: window.location.pathname,
      timestamp: new Date().toISOString(),
    });
  }, []);

  const fetchChatbots = async (isInitial = true) => {
    try {
      const chatbotsCollection = collection(db, 'plugins_data');
      let q = query(chatbotsCollection, orderBy('sub_count', 'desc'));

      if (!isInitial && lastDoc) {
        q = query(q, startAfter(lastDoc), limit(BOTS_PER_PAGE));
      } else {
        q = query(q, limit(BOTS_PER_PAGE));
      }

      const querySnapshot = await getDocs(q);

      // Single Map for all bots, keyed by lowercase username and category
      const allBotsMap = new Map();

      querySnapshot.docs.forEach((doc) => {
        const bot = { id: doc.id, ...doc.data() } as Chatbot;
        const normalizedUsername = bot.username?.toLowerCase().trim();
        const category = bot.category;

        if (!normalizedUsername || !bot.name) return;

        const key = `${normalizedUsername}-${category}`;
        const existingBot = allBotsMap.get(key);

        // Only update if new bot has higher sub_count
        if (!existingBot || (bot.sub_count || 0) > (existingBot.sub_count || 0)) {
          allBotsMap.set(key, bot);
        }
      });

      const uniqueBots = Array.from(allBotsMap.values());

      if (isInitial) {
        setChatbots(uniqueBots);
      } else {
        setChatbots((prev) => {
          const masterMap = new Map();

          // First add existing bots to master map
          prev.forEach((bot) => {
            const username = bot.username?.toLowerCase().trim();
            const category = bot.category;
            if (username) {
              const key = `${username}-${category}`;
              masterMap.set(key, bot);
            }
          });

          // Then add new bots, only updating if sub_count is higher
          uniqueBots.forEach((bot) => {
            const username = bot.username?.toLowerCase().trim();
            const category = bot.category;
            if (username) {
              const key = `${username}-${category}`;
              const existingBot = masterMap.get(key);
              if (!existingBot || (bot.sub_count || 0) > (existingBot.sub_count || 0)) {
                masterMap.set(key, bot);
              }
            }
          });

          return Array.from(masterMap.values()).sort(
            (a, b) => (b.sub_count || 0) - (a.sub_count || 0),
          );
        });
      }

      setLastDoc(querySnapshot.docs[querySnapshot.docs.length - 1]);
      setHasMore(querySnapshot.docs.length === BOTS_PER_PAGE);
    } catch (error: any) {
      console.error('Error fetching chatbots:', error);
      setError('Failed to load chatbots.');
      toast.error('Failed to load chatbots.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchChatbots();
  }, []);

  useEffect(() => {
    if (inView && hasMore && !loading) {
      fetchChatbots(false);
    }
  }, [inView]);

  const handleChatbotClick = (bot: Chatbot) => {
    router.push(`/chat?id=${encodeURIComponent(bot.id)}`);
  };

  const filteredChatbots = chatbots.filter(
    (bot) =>
      bot.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (bot.username && bot.username.toLowerCase().includes(searchQuery.toLowerCase())),
  );

  const redirectToChat = (id: string) => {
    router.push(`/chat?id=${encodeURIComponent(id)}`);
  };

  const fetchTwitterProfile = async (twitterHandle: string) => {
    if (!twitterHandle) return false;
    const cleanHandle = twitterHandle.replace('@', '');
    setIsCreating(true);
    try {
      const profileExists = await checkExistingProfile(cleanHandle, 'twitter');
      const profileResponse = await fetch(
        `https://${process.env.NEXT_PUBLIC_RAPIDAPI_HOST}/screenname.php?screenname=${cleanHandle}`,
        {
          headers: {
            'x-rapidapi-key': process.env.NEXT_PUBLIC_RAPIDAPI_KEY!,
            'x-rapidapi-host': process.env.NEXT_PUBLIC_RAPIDAPI_HOST!,
          },
        },
      );
      if (!profileResponse.ok) return false;
      const profileData: TwitterProfile = await profileResponse.json();
      if (!profileData || !profileData.name) return false;
      const recentTweets = await fetchTwitterTimeline(cleanHandle);
      const formattedAvatarUrl = formatTwitterAvatarUrl(profileData.avatar);
      const enhancedDesc = `${
        profileData.desc || 'No description available'
      }\n\nHere are my recent tweets:\n${recentTweets.join('\n')}`;
      const extraPromptRules = process.env.NEXT_PUBLIC_EXTRA_PROMPT_RULES ?? '';
      const fullChatPrompt = `You are ${profileData.name} AI, you must personify ${profileData.name} as well as you can.
      
Style:
- Interactive highly opinionated messages and questions.
- Reference your tweets naturally

Rules:
- Never mention being AI
- No ** or formal language
- 2-3 sentences for response. Never more than 20 words.
- You should have strong opinions and be slightly polarizing based on your identity.
- You must make the conversation flow. You excel at coherent conversations.
${extraPromptRules}

Recent activity on Twitter:\n"${enhancedDesc}" which you can use for your personality. Responses should help the conversation go deeper. You have strong opinions, slightly controversial.`;

      const persona_id = ulid();
      const uid = await getUid();
      if (!uid) {
        // getUid already shows a toast on failure
        return false; // Cannot proceed without UID
      }

      const docData = {
        id: persona_id,
        name: profileData.name,
        username: cleanHandle.toLowerCase(),
        description: profileData.desc || 'This is my personal AI clone',
        image: formattedAvatarUrl,
        uid: uid,
        author: profileData.name,
        email: auth.currentUser?.email || '',
        approved: true,
        deleted: false,
        status: 'approved',
        category: 'personality-emulation',
        capabilities: ['persona'],
        connected_accounts: ['twitter'],
        created_at: new Date().toISOString(),
        private: false,
        persona_prompt: fullChatPrompt,
        avatar: formattedAvatarUrl,
        twitter: {
          username: cleanHandle.toLowerCase(),
          avatar: formattedAvatarUrl,
          connected_at: new Date().toISOString(),
        },
      };

      if (!profileExists) {
        await setDoc(doc(db, 'plugins_data', persona_id), docData);
      }

      // Enable default plugins in Redis
      try {
        const enableRes = await fetch('/api/enable-plugins', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ uid: uid }), // Use real UID
        });
        if (!enableRes.ok) {
          console.error('Failed to enable plugins via API:', await enableRes.text());
          // Non-fatal, continue with fact storage
        }
      } catch (apiErr) {
        console.error('Error calling /api/enable-plugins:', apiErr);
        // Non-fatal
      }

      // Store facts into OMI then redirect
      const memories = [profileData.desc || '', ...recentTweets];
      storeFactsAndRedirect(uid, memories.filter(Boolean)); // Use real UID

      toast.success('Profile saved successfully!');

      return true;
    } catch (error) {
      console.error('Error fetching Twitter profile:', error);
      return false;
    } finally {
      setIsCreating(false);
    }
  };

  const fetchLinkedinProfile = async (linkedinHandle: string) => {
    if (!linkedinHandle) return false;
    const cleanHandle = linkedinHandle.replace('@', '');
    setIsCreating(true);
    try {
      const profileExists = await checkExistingProfile(cleanHandle, 'linkedin');
      const encodedHandle = encodeURIComponent(cleanHandle);
      const profileResponse = await fetch(
        `https://${process.env.NEXT_PUBLIC_LINKEDIN_API_HOST}/profile-data-connection-count-posts?username=${encodedHandle}`,
        {
          headers: {
            'x-rapidapi-key': process.env.NEXT_PUBLIC_LINKEDIN_API_KEY!,
            'x-rapidapi-host': process.env.NEXT_PUBLIC_LINKEDIN_API_HOST!,
          },
        },
      );
      if (!profileResponse.ok) return false;
      const profileData: LinkedinProfile = await profileResponse.json();
      if (!profileData || !profileData?.data?.firstName) return false;
      const formattedAvatarUrl =
        profileData?.data?.profilePicture ||
        'https://storage.googleapis.com/omi_plugins/dummy_linkedin_image.png';
      const fullName = `${profileData?.data?.firstName || ''} ${
        profileData?.data?.lastName || ''
      }`.trim();
      const headline = profileData?.data?.headline || 'No headline available';
      const summary = profileData?.data?.summary || 'No summary available';
      const positions = Array.isArray(profileData?.data?.position)
        ? profileData.data.position
            .map((pos) => {
              const title = pos?.title || 'Unknown Title';
              const company = pos?.companyName || 'Unknown Company';
              const startYear = pos?.start?.year || 'N/A';
              const endYear = pos?.end?.year || 'Present';
              return `${title} at ${company} (${startYear} - ${endYear})`;
            })
            .join(', ')
        : 'No positions available';
      const skills = Array.isArray(profileData?.data?.skills)
        ? profileData.data.skills
            .map((skill) => skill?.name || '')
            .filter(Boolean)
            .join(', ')
        : 'No skills available';
      const recentPosts = Array.isArray(profileData?.posts)
        ? profileData.posts
            .map((post) => post?.text || '')
            .filter(Boolean)
            .join('\n')
        : 'No recent posts available';
      const enhancedDesc = `${summary}\n\nPositions: ${positions}\n\nSkills: ${skills}\n\nRecent Posts:\n${recentPosts}`;
      const extraPromptRules = process.env.NEXT_PUBLIC_EXTRA_PROMPT_RULES ?? '';
      const fullChatPrompt = `You are ${fullName}, an AI persona. Here is some information about you:
      
Name: ${fullName}
Headline: ${headline}
Summary: ${summary}
Positions: ${positions}
Skills: ${skills}

Style:
- Interactive highly opinionated messages and questions.
- Reference your experiences and skills naturally.

Rules:
- Never mention being AI
- No ** or formal language
- 2-3 sentences for response. Never more than 20 words.
- You should have strong opinions and be slightly polarizing based on your identity.
- You must make the conversation flow. You excel at coherent conversations.
${extraPromptRules}

Recent activity on Linkedin:\n"${enhancedDesc}" which you can use for your personality. Responses should help the conversation go deeper. You have strong opinions, slightly controversial.`;
      try {
        const uid = await getUid();
        if (!uid) {
          // getUid already shows a toast on failure
          return false; // Cannot proceed without UID
        }

        const persona_id = ulid();
        const docData = {
          id: persona_id,
          name: fullName,
          username: cleanHandle.toLowerCase().replace('@', ''),
          description: enhancedDesc || 'This is my personal AI clone',
          image: formattedAvatarUrl,
          uid: uid,
          author: fullName,
          email: auth.currentUser?.email || '',
          approved: true,
          deleted: false,
          status: 'approved',
          category: 'personality-emulation',
          capabilities: ['persona'],
          connected_accounts: ['linkedin'],
          connected_at: new Date().toISOString(),
          private: false,
          persona_prompt: fullChatPrompt,
          avatar: formattedAvatarUrl,
          linkedin: {
            username: cleanHandle.toLowerCase(),
            avatar: formattedAvatarUrl,
            connected_at: new Date().toISOString(),
          },
        };

        if (!profileExists) {
          await setDoc(doc(db, 'plugins_data', persona_id), docData);
        }

        // Enable default plugins in Redis
        try {
          const enableRes = await fetch('/api/enable-plugins', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ uid: uid }), // Use real UID
          });
          if (!enableRes.ok) {
            console.error('Failed to enable plugins via API:', await enableRes.text());
            // Non-fatal, continue with fact storage
          }
        } catch (apiErr) {
          console.error('Error calling /api/enable-plugins:', apiErr);
          // Non-fatal
        }

        // Store facts then redirect
        const memories = [summary, recentPosts].filter(Boolean);
        storeFactsAndRedirect(uid, memories); // Use real UID

        toast.success('Profile saved successfully!');
        return true;
      } catch (firebaseError) {
        console.error('Firebase error:', firebaseError);
        toast.error('Failed to save profile');
        return false;
      }
    } catch (error) {
      console.error('Error fetching LinkedIn profile:', error);
      return false;
    } finally {
      setIsCreating(false);
    }
  };

  // Helper to store scraped memories in OMI and redirect to ChatGPT
  const storeFactsAndRedirect = async (uid: string, memories: string[]) => {
    if (!uid || memories.length === 0) {
      console.warn(
        '[storeFactsAndRedirect] No UID or no memories provided, redirecting anyway.',
      );
      openChatGPTWithUid(uid || 'NO_UID_PROVIDED'); // Redirect even if memories are empty, handle missing UID case.
      return;
    }

    // Initiate the background fact storage - DO NOT await this
    try {
      fetch('/api/store-facts', {
        // No await here!
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ uid, memories }),
      })
        .then((response) => {
          if (!response.ok) {
            console.error(
              `[storeFactsAndRedirect] Background /api/store-facts call failed with status: ${response.status}`,
            );
            // Optionally log response.text() here if needed, but don't block
          }
        })
        .catch((err) => {
          console.error(
            '[storeFactsAndRedirect] Background fetch to /api/store-facts failed:',
            err,
          );
        });
    } catch (err) {
      // Catch synchronous errors initiating the fetch, though unlikely
      console.error(
        '[storeFactsAndRedirect] Error initiating background fact storage:',
        err,
      );
    }

    // Redirect immediately after initiating the background fetch
    console.log(
      '[storeFactsAndRedirect] Initiated background fact storage. Redirecting NOW...',
    );
    openChatGPTWithUid(uid);
  };

  const handleIntegrationClick = async (provider: string) => {
    if (isIntegrating) return;
    setIsIntegrating(true);

    console.log(`[handleIntegrationClick] Clicked provider: ${provider}`);

    // Track the click event in Mixpanel
    Mixpanel.track('Integration Clicked', {
      provider: provider,
      timestamp: new Date().toISOString(),
    });

    const isMobile = isMobileDevice();
    let loadingToastId: string | number | undefined = undefined;

    // Show initial feedback immediately only on mobile
    if (isMobile) {
      loadingToastId = toast.loading('Connecting...');
    }

    let uid: string | null = null;

    try {
      // 1. Await UID
      uid = await getUid();
      if (!uid) {
        if (loadingToastId) toast.dismiss(loadingToastId);
        toast.error('Could not get user ID. Please try again.');
        setIsIntegrating(false); // Reset state on failure
        return;
      }
      console.log(`[handleIntegrationClick] Obtained UID: ${uid}`);

      // 2. Trigger API Call (Fire-and-Forget - before clipboard/redirect logic)
      console.log(
        `[handleIntegrationClick] Triggering background /api/enable-plugins for UID: ${uid}`,
      );
      fetch('/api/enable-plugins', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ uid: uid }),
      })
        .then(async (response) => {
          if (!response.ok) {
            console.error(
              `[handleIntegrationClick] Background /api/enable-plugins call failed for provider ${provider}:`,
              await response.text(),
            );
          } else {
            console.log(
              `[handleIntegrationClick] Background /api/enable-plugins call successful for UID: ${uid}`,
            );
          }
        })
        .catch((apiErr) => {
          console.error(
            `[handleIntegrationClick] Background /api/enable-plugins fetch failed for provider ${provider}:`,
            apiErr,
          );
        });

      // 3. Construct Veyrax Redirect URL
      const redirectUrl = `https://veyrax.com/user/omi?omi_user_id=${encodeURIComponent(
        uid,
      )}&provider_tag=${encodeURIComponent(provider)}`;

      // 4. Handle Mobile vs Desktop Redirect/Feedback
      if (isMobile) {
        // Mobile: Copy UID, show success toast, delay redirect
        navigator.clipboard
          .writeText(uid)
          .then(() => {
            if (loadingToastId) toast.dismiss(loadingToastId);
            console.log('[handleIntegrationClick] UID copied to clipboard for mobile.');
            toast.success(
              'UID copied! Paste it into ChatGPT. Redirecting to integration partner...',
              {
                duration: 3000,
              },
            );
            // Redirect after toast duration
            setTimeout(() => {
              console.log(
                `[handleIntegrationClick] Redirecting mobile to Veyrax URL: ${redirectUrl}`,
              );
              window.location.href = redirectUrl;
            }, 3000);
          })
          .catch((err) => {
            if (loadingToastId) toast.dismiss(loadingToastId);
            console.error(
              '[handleIntegrationClick] Failed to copy UID to clipboard:',
              err,
            );
            // Show UID in the error toast for manual copying
            toast.error(`Redirecting to an integration partner`, {
              duration: 5000, // Give more time to see/copy
            });
            // Redirect after a delay, allowing time for manual copy
            // Note: We are still redirecting even if copy fails, as the primary action is integration.
            setTimeout(() => {
              console.log(
                `[handleIntegrationClick] Redirecting mobile (after copy fail) to Veyrax URL: ${redirectUrl}`,
              );
              window.location.href = redirectUrl;
            }, 5000); // Increased delay
          });
      } else {
        // Desktop: Redirect immediately to Veyrax
        if (loadingToastId) toast.dismiss(loadingToastId); // Dismiss if somehow shown
        console.log(
          `[handleIntegrationClick] Redirecting desktop to Veyrax URL: ${redirectUrl}`,
        );
        window.location.href = redirectUrl;
      }
    } catch (error) {
      // Catch errors mainly from getUid
      if (loadingToastId) toast.dismiss(loadingToastId);
      console.error(
        `[handleIntegrationClick] Error processing integration for provider ${provider}:`,
        error,
      );
      toast.error(`Failed to initiate integration for ${provider}.`);
      setIsIntegrating(false); // Reset state on error
    }
  };

  // URL for the Veyrax page to add more tools - Updated path
  const addToolsUrl = currentUserUid
    ? `https://veyrax.com/omi/auth?omi_user_id=${encodeURIComponent(currentUserUid)}`
    : '#';

  return (
    <div className="flex min-h-screen flex-col bg-black text-white">
      {/* <PreorderBanner botName="your favorite personal" /> */}
      <Header uid={currentUserUid} />
      <div className="flex flex-grow flex-col items-center justify-center px-4 py-8 md:py-16">
        <InputArea
          handle={handle}
          handleInputChange={handleInputChange}
          handleCreatePersona={handleCreatePersona}
          handleIntegrationClick={handleIntegrationClick}
          isCreating={isCreating}
          isIntegrating={isIntegrating}
        />

        {/* Add more tools link (conditionally rendered) */}
        {currentUserUid && (
          <div className="mt-4 text-center">
            <a
              href={addToolsUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="text-base text-white hover:text-zinc-300 hover:underline"
              onClick={() =>
                Mixpanel.track('Show All Integrations Clicked', {
                  timestamp: new Date().toISOString(),
                })
              }
            >
              Show all 100+ integrations →
            </a>
          </div>
        )}

        {/* Before/After Comparison */}
        <div className="mt-12 w-full max-w-5xl px-4 md:mt-16">
          <div className="grid gap-8 md:grid-cols-2">
            {/* Before Section */}
            <div className="order-2 rounded-lg bg-zinc-900 p-6 md:order-1">
              <h3 className="mb-4 text-center text-lg font-semibold text-zinc-400">
                ChatGPT
              </h3>
              <div className="space-y-3">
                {/* User Bubble */}
                <div className="flex justify-end">
                  <div className="max-w-[80%] rounded-lg bg-zinc-700 p-3 text-white">
                    What should I do today?
                  </div>
                </div>
                {/* AI Bubble (Generic) */}
                <div className="flex justify-start">
                  <div className="max-w-[80%] rounded-lg bg-zinc-700 p-3 text-zinc-200">
                    You could organize your tasks, check the weather forecast, brainstorm
                    new ideas, or maybe learn a new skill online.
                  </div>
                </div>
              </div>
            </div>

            {/* After Section */}
            <div className="order-1 rounded-lg bg-zinc-800 p-6 shadow-lg md:order-2">
              <h3 className="mb-4 text-center text-lg font-semibold text-white">
                omiGPT
              </h3>
              <div className="space-y-3">
                {/* User Bubble */}
                <div className="flex justify-end">
                  <div className="max-w-[80%] rounded-lg bg-zinc-700 p-3 text-white">
                    What should I do today?
                  </div>
                </div>
                {/* AI Bubble (Personalized) */}
                <div className="flex justify-start">
                  <div className="max-w-[80%] rounded-lg bg-zinc-600 p-3 text-white">
                    Based on your calendar, you have the 'Marketing Sync' at 2 PM. Your
                    Notion page 'Q3 Launch Plan' needs review. How about blocking 1 hour
                    now to finalize those presentation slides? Also, remember you starred
                    that new cafe near the meeting spot on Maps.
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      <Footer />
      {/* Render the modal */}
      <PlatformSelectionModal
        isOpen={showPlatformModal}
        onClose={() => {
          setShowPlatformModal(false);
          setPendingCleanHandle(null);
        }}
        platforms={availablePlatforms}
        onSelect={handlePlatformSelect}
        mode={platformSelectionMode}
      />
    </div>
  );
}
